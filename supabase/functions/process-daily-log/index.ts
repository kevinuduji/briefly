// deno-lint-ignore-file no-explicit-any
import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

type Body = {
  transcript?: string;
  audioStoragePath?: string;
  businessName?: string;
  businessType?: string;
  businessDescription?: string;
  primaryGoal?: string;
  /** When user confirms structured fields client-side, use this instead of re-extracting. */
  structuredOverride?: Record<string, unknown>;
};

async function openAIChat(
  apiKey: string,
  messages: { role: "system" | "user"; content: string }[],
  jsonMode = true,
): Promise<string> {
  const res = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: "gpt-4o-mini",
      temperature: 0.2,
      response_format: jsonMode ? { type: "json_object" } : undefined,
      messages,
    }),
  });
  if (!res.ok) {
    const t = await res.text();
    throw new Error(`OpenAI chat failed: ${res.status} ${t}`);
  }
  const data = await res.json();
  return data.choices?.[0]?.message?.content ?? "";
}

async function whisperFromStorage(
  supabaseUrl: string,
  serviceKey: string,
  bucket: string,
  path: string,
  openAIKey: string,
): Promise<string> {
  const fileUrl = `${supabaseUrl}/storage/v1/object/${bucket}/${path}`;
  const r = await fetch(fileUrl, {
    headers: { Authorization: `Bearer ${serviceKey}` },
  });
  if (!r.ok) {
    throw new Error(`Failed to fetch audio: ${r.status}`);
  }
  const buf = await r.arrayBuffer();
  const blob = new Blob([buf], { type: "audio/mp4" });
  const form = new FormData();
  form.append("file", blob, "audio.m4a");
  form.append("model", "whisper-1");
  const tr = await fetch("https://api.openai.com/v1/audio/transcriptions", {
    method: "POST",
    headers: { Authorization: `Bearer ${openAIKey}` },
    body: form,
  });
  if (!tr.ok) {
    const t = await tr.text();
    throw new Error(`Whisper failed: ${tr.status} ${t}`);
  }
  const j = await tr.json();
  return j.text as string;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const openAIKey = Deno.env.get("OPENAI_API_KEY");
    if (!openAIKey) {
      return new Response(JSON.stringify({ error: "Missing OPENAI_API_KEY" }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

    const body = (await req.json()) as Body;
    let transcript = body.transcript?.trim() ?? "";

    if (!transcript && body.audioStoragePath) {
      if (!serviceKey) {
        return new Response(JSON.stringify({ error: "Server missing service role for audio fetch" }), {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }
      transcript = await whisperFromStorage(
        supabaseUrl,
        serviceKey,
        "briefly-audio",
        body.audioStoragePath,
        openAIKey,
      );
    }

    if (!transcript) {
      return new Response(JSON.stringify({ error: "transcript or audioStoragePath required" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const systemShape = `You are Briefly, a voice-first business operating assistant for small business owners.
Rules:
- Never invent exact numbers the user did not provide. Use null for unknown numeric fields.
- Prefer qualitative signals when quantities are unclear.
- Output MUST be valid JSON only, matching this shape:
{
  "cleanedSummary": string,
  "confidenceNotes": string,
  "structured": {
    "keySignals": string[],
    "risks": string[],
    "productSignals": string[],
    "inventoryNotes": string[],
    "customerFeedback": string[],
    "issues": string[],
    "decisionsMentioned": string[],
    "trends": string[]
  },
  "metrics": {
    "traffic": number | null,
    "salesCount": number | null,
    "conversionEstimate": number | null,
    "inventoryStatus": string | null,
    "inventoryRiskLevel": "low"|"medium"|"high"|null,
    "trendNotes": string | null,
    "metricConfidence": "high"|"medium"|"low"
  },
  "actions": {
    "title": string,
    "reason": string,
    "priority": "high"|"medium"|"low",
    "category": string,
    "expectedImpact": string,
    "followUpDate": string | null
  }[]
}
Provide 1 to 3 actions. Each action must cite specific signals from the transcript (no generic consultant advice).`;

    if (body.structuredOverride) {
      const confirmSystem =
        `${systemShape}\n\nThe user has CONFIRMED structured fields. Use structuredOverride as ground truth for signals. Still ground actions in transcript + structuredOverride.`;
      const userCtx = [
        body.businessName ? `Business name: ${body.businessName}` : "",
        body.businessType ? `Business type: ${body.businessType}` : "",
        body.businessDescription ? `Description: ${body.businessDescription}` : "",
        body.primaryGoal ? `Primary goal: ${body.primaryGoal}` : "",
        `structuredOverride JSON:\n${JSON.stringify(body.structuredOverride)}`,
        `Transcript:\n${transcript}`,
      ].filter(Boolean).join("\n");

      const raw = await openAIChat(openAIKey, [
        { role: "system", content: confirmSystem },
        { role: "user", content: userCtx },
      ], true);

      let parsed: any;
      try {
        parsed = JSON.parse(raw);
      } catch {
        return new Response(JSON.stringify({ error: "Model returned non-JSON", raw }), {
          status: 502,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      const structured = body.structuredOverride as any;
      const briefText = [
        parsed.cleanedSummary,
        structured?.keySignals?.length
          ? `Signals: ${structured.keySignals.join("; ")}`
          : "",
        parsed.actions?.length ? `Next: ${parsed.actions[0]?.title}` : "",
      ].filter(Boolean).join("\n");

      return new Response(
        JSON.stringify({
          transcript,
          cleanedSummary: parsed.cleanedSummary,
          confidenceNotes: parsed.confidenceNotes,
          structuredData: structured,
          metrics: parsed.metrics ?? {},
          actions: parsed.actions ?? [],
          briefText,
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const raw = await openAIChat(openAIKey, [
      { role: "system", content: systemShape },
      {
        role: "user",
        content: [
          body.businessName ? `Business name: ${body.businessName}` : "",
          body.businessType ? `Business type: ${body.businessType}` : "",
          body.businessDescription ? `Description: ${body.businessDescription}` : "",
          body.primaryGoal ? `Primary goal: ${body.primaryGoal}` : "",
          `Transcript:\n${transcript}`,
        ].filter(Boolean).join("\n"),
      },
    ], true);

    let parsed: any;
    try {
      parsed = JSON.parse(raw);
    } catch {
      return new Response(JSON.stringify({ error: "Model returned non-JSON", raw }), {
        status: 502,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const briefText = [
      parsed.cleanedSummary,
      parsed.structured?.keySignals?.length
        ? `Signals: ${parsed.structured.keySignals.join("; ")}`
        : "",
      parsed.actions?.length ? `Next: ${parsed.actions[0]?.title}` : "",
    ].filter(Boolean).join("\n");

    return new Response(
      JSON.stringify({
        transcript,
        cleanedSummary: parsed.cleanedSummary,
        confidenceNotes: parsed.confidenceNotes,
        structuredData: parsed.structured ?? {},
        metrics: parsed.metrics ?? {},
        actions: parsed.actions ?? [],
        briefText,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
