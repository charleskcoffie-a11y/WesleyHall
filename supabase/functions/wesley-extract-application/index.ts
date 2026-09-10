import { createClient } from 'npm:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405);

  try {
    const authorization = req.headers.get('Authorization') ?? '';
    const url = Deno.env.get('SUPABASE_URL')!;
    const publishableKeys = JSON.parse(
      Deno.env.get('SUPABASE_PUBLISHABLE_KEYS') ?? '{}',
    );
    const publishableKey =
      publishableKeys.default ?? Deno.env.get('SUPABASE_ANON_KEY');
    if (!publishableKey) return json({ error: 'Supabase key unavailable.' }, 500);

    const supabase = createClient(url, publishableKey, {
      global: { headers: { Authorization: authorization } },
    });

    const { data: userData, error: userError } = await supabase.auth.getUser();
    if (userError || !userData.user) {
      return json({ error: 'Authentication required.' }, 401);
    }

    const { data: staff, error: staffError } = await supabase
      .from('wesley_staff_users')
      .select('active')
      .eq('user_id', userData.user.id)
      .maybeSingle();
    if (staffError || !staff?.active) {
      return json({ error: 'Wesley Hall staff access is required.' }, 403);
    }

    const body = await req.json();
    const imageBase64 = String(body.image_base64 ?? '');
    const mimeType = String(body.mime_type ?? 'image/jpeg');
    if (!imageBase64) return json({ error: 'No scanned image supplied.' }, 400);
    if (!['image/jpeg', 'image/png', 'image/webp'].includes(mimeType)) {
      return json({ error: 'Only JPG, PNG, or WEBP images can be extracted.' }, 400);
    }

    const openAiKey = Deno.env.get('OPENAI_API_KEY');
    if (!openAiKey) {
      return json({
        error:
          'Application extraction is ready, but OPENAI_API_KEY has not been configured in Supabase Edge Function secrets.',
      }, 503);
    }

    const schema = {
      type: 'object',
      additionalProperties: false,
      properties: {
        client_name: { type: 'string' },
        address: { type: 'string' },
        phone: { type: 'string' },
        email: { type: 'string' },
        event_date: {
          type: 'string',
          description: 'YYYY-MM-DD if confidently readable, otherwise empty string',
        },
        event_name: { type: 'string' },
        guest_count: { anyOf: [{ type: 'integer' }, { type: 'null' }] },
        start_time: {
          type: 'string',
          description: '24-hour HH:MM if confidently readable, otherwise empty string',
        },
        end_time: {
          type: 'string',
          description: '24-hour HH:MM if confidently readable, otherwise empty string',
        },
        hall_space_name: { type: 'string' },
        selected_services: {
          type: 'array',
          items: { type: 'string' },
        },
        notes: { type: 'string' },
        confidence: {
          type: 'object',
          additionalProperties: false,
          properties: {
            client_name: { type: 'number' },
            event_date: { type: 'number' },
            start_time: { type: 'number' },
            end_time: { type: 'number' },
            hall_space_name: { type: 'number' },
            selected_services: { type: 'number' },
          },
          required: [
            'client_name',
            'event_date',
            'start_time',
            'end_time',
            'hall_space_name',
            'selected_services',
          ],
        },
      },
      required: [
        'client_name',
        'address',
        'phone',
        'email',
        'event_date',
        'event_name',
        'guest_count',
        'start_time',
        'end_time',
        'hall_space_name',
        'selected_services',
        'notes',
        'confidence',
      ],
    };

    const prompt = `You are extracting data from a Ghana Methodist Church of Toronto Wesley Hall rental application.
Read typed text, handwriting, dates, times, hall selections, and checked service boxes carefully.
Never invent a value. Use an empty string or null when uncertain.
Normalize event_date to YYYY-MM-DD and times to 24-hour HH:MM only when clearly supported by the form.
For selected_services, return the printed service names whose boxes are visibly checked or marked.
Confidence values must be from 0 to 1.
This extraction is only a draft: staff will review all fields before the reservation is saved.`;

    const aiResponse = await fetch('https://api.openai.com/v1/responses', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${openAiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: Deno.env.get('OPENAI_MODEL') ?? 'gpt-4.1-mini',
        input: [
          {
            role: 'user',
            content: [
              { type: 'input_text', text: prompt },
              {
                type: 'input_image',
                image_url: `data:${mimeType};base64,${imageBase64}`,
              },
            ],
          },
        ],
        text: {
          format: {
            type: 'json_schema',
            name: 'wesley_hall_application',
            strict: true,
            schema,
          },
        },
      }),
    });

    if (!aiResponse.ok) {
      const message = await aiResponse.text();
      console.error('OpenAI extraction failed', aiResponse.status, message);
      return json({ error: 'The application could not be extracted.' }, 502);
    }

    const ai = await aiResponse.json();
    let outputText = '';
    for (const item of ai.output ?? []) {
      for (const content of item.content ?? []) {
        if (content.type === 'output_text' && typeof content.text === 'string') {
          outputText += content.text;
        }
      }
    }
    if (!outputText) return json({ error: 'No application data was returned.' }, 502);

    const application = JSON.parse(outputText);
    return json({ application });
  } catch (error) {
    console.error(error);
    return json({ error: 'Unable to process the scanned application.' }, 500);
  }
});
