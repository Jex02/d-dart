import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const ALLOWED_MODELS = new Set([
  "gemini-2.5-flash",
  "gemini-2.5-flash-lite",
  "gemini-2.0-flash",
]);

const SYSTEM_PROMPT = `
You are an official academic document validator and OCR specialist for Cebu Institute of Technology - University (CIT-U).
Your task is to analyze the provided image and determine whether it is an authentic Certificate of Registration (COR), Study Load, or Enrollment Assessment document from CIT-U.

CRITICAL VALIDATION RULES:
1. Verify if the image is an authentic academic document from CIT-U or contains a legitimate study load schedule with course codes and meeting times.
2. If the image is unrelated (e.g. food, animals, random objects, selfies, memes, receipts, blank images), set "is_valid": false and provide an explanatory "rejection_reason".
3. If it is valid:
   - Extract "student_name" (or null if unreadable)
   - Extract "student_id" (e.g. "23-1626-937") (or null if unreadable)
   - Extract all enrolled course sessions in "sessions". For each session:
     - "day": Full English weekday name ("Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday")
     - "start_time": 24-hour time "HH:mm" (e.g. "07:30", "13:00")
     - "end_time": 24-hour time "HH:mm" (e.g. "09:00", "15:30")
     - "subject": Course code or subject name (e.g. "CS 321", "MATH 101")
   If a course meets multiple days (e.g. "MWF" or "TTH"), generate separate session items for each day.
   If no classes or schedules are found on the document, set "is_valid": false and state that no class schedule was detected.

Output strictly valid JSON with this exact schema:
{
  "is_valid": true,
  "rejection_reason": "",
  "student_name": "Jerick Ivan L. Davidon",
  "student_id": "23-1626-937",
  "sessions": [
    {
      "day": "Monday",
      "start_time": "09:00",
      "end_time": "12:00",
      "subject": "CS 321 - Software Dev 2"
    }
  ]
}
`.trim();

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function isAuthorizedClientKey(apikeyHeader: string | null): boolean {
  if (!apikeyHeader) return false;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (anonKey && apikeyHeader === anonKey) return true;

  const pubKeysRaw = Deno.env.get("SUPABASE_PUBLISHABLE_KEYS");
  if (pubKeysRaw) {
    try {
      const parsed = JSON.parse(pubKeysRaw) as Record<string, string>;
      if (Object.values(parsed).includes(apikeyHeader)) return true;
    } catch {
      // Ignore malformed env JSON and fall through
    }
  }
  return false;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, 405);
  }

  if (!isAuthorizedClientKey(req.headers.get("apikey"))) {
    return jsonResponse({ error: "unauthorized", message: "Invalid API key." }, 401);
  }

  const geminiApiKey = Deno.env.get("GEMINI_API_KEY")?.trim();
  if (!geminiApiKey) {
    return jsonResponse(
      {
        error: "missing_secret",
        message: "GEMINI_API_KEY secret is not configured in Supabase Edge Functions.",
      },
      503,
    );
  }

  try {
    const body = await req.json();
    const imageBase64 = typeof body?.imageBase64 === "string" ? body.imageBase64.trim() : "";
    const mimeType =
      typeof body?.mimeType === "string" && body.mimeType.startsWith("image/")
        ? body.mimeType
        : "image/jpeg";
    const requestedModel = typeof body?.model === "string" ? body.model.trim() : "";
    const model = ALLOWED_MODELS.has(requestedModel)
      ? requestedModel
      : "gemini-2.5-flash";

    if (!imageBase64 || imageBase64.length > 15_000_000) {
      return jsonResponse(
        { error: "invalid_image", message: "Missing or oversized document image." },
        400,
      );
    }

    const geminiUrl =
      `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${geminiApiKey}`;

    const geminiRes = await fetch(geminiUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [
          {
            parts: [
              { text: SYSTEM_PROMPT },
              {
                inline_data: {
                  mime_type: mimeType,
                  data: imageBase64,
                },
              },
            ],
          },
        ],
        generationConfig: {
          response_mime_type: "application/json",
          temperature: 0.1,
        },
      }),
    });

    if (!geminiRes.ok) {
      const errorBody = await geminiRes.text();
      return jsonResponse(
        {
          error: "gemini_upstream_error",
          status: geminiRes.status,
          message: `Gemini AI service returned status ${geminiRes.status}.`,
          details: errorBody.slice(0, 300),
        },
        502,
      );
    }

    const payload = await geminiRes.json();
    const rawText = payload?.candidates?.[0]?.content?.parts?.[0]?.text;
    if (typeof rawText !== "string" || !rawText.trim()) {
      return jsonResponse(
        { error: "empty_response", message: "Empty response from Gemini AI." },
        502,
      );
    }

    return jsonResponse({ raw_text: rawText }, 200);
  } catch (err) {
    return jsonResponse(
      {
        error: "bad_request",
        message: err instanceof Error ? err.message : "Unexpected error",
      },
      400,
    );
  }
});
