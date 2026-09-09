import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const {
      startDate,
      endDate,
      dhis2Url,
      dhis2Username,
      dhis2Password,
      orgUnit,
    } = await req.json()

    if (!startDate || !endDate || !dhis2Url || !dhis2Username || !orgUnit) {
      return new Response(
        JSON.stringify({ error: 'startDate, endDate, dhis2Url, dhis2Username, and orgUnit are required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    )

    // Fetch completed incidents in the date range
    const { data: incidents, error: dbError } = await supabase
      .from('incidents')
      .select('id, status, nature_of_emergency, created_at, arrived_at, completed_at')
      .eq('status', 'completed')
      .gte('created_at', `${startDate}T00:00:00Z`)
      .lte('created_at', `${endDate}T23:59:59Z`)

    if (dbError) {
      return new Response(
        JSON.stringify({ error: dbError.message }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    // Calculate aggregate metrics
    const totalCompleted = incidents?.length ?? 0
    const responseTimes = (incidents ?? [])
      .filter((i) => i.arrived_at != null)
      .map((i) => {
        const created = new Date(i.created_at).getTime()
        const arrived = new Date(i.arrived_at).getTime()
        return Math.round((arrived - created) / 60000)
      })
    const avgResponseMins =
      responseTimes.length > 0
        ? Math.round(responseTimes.reduce((a, b) => a + b, 0) / responseTimes.length)
        : 0

    // DHIS2 period: YYYYMM from startDate
    const period = startDate.replace(/-/g, '').substring(0, 6)

    const dataValueSet = {
      dataValues: [
        {
          dataElement: 'erams_total_completed_incidents',
          period,
          orgUnit,
          value: String(totalCompleted),
        },
        {
          dataElement: 'erams_avg_response_time_mins',
          period,
          orgUnit,
          value: String(avgResponseMins),
        },
      ],
    }

    const dhis2Res = await fetch(`${dhis2Url}/api/dataValueSets`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Basic ${btoa(`${dhis2Username}:${dhis2Password}`)}`,
      },
      body: JSON.stringify(dataValueSet),
    })

    const dhis2Body = await dhis2Res.json()

    return new Response(
      JSON.stringify({
        status: dhis2Body.status ?? (dhis2Res.ok ? 'SUCCESS' : 'ERROR'),
        httpStatus: dhis2Body.httpStatus ?? String(dhis2Res.status),
        totalExported: totalCompleted,
        period,
        dhis2Response: dhis2Body,
      }),
      {
        status: dhis2Res.ok ? 200 : dhis2Res.status,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      },
    )
  } catch (err) {
    return new Response(
      JSON.stringify({ error: String(err) }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )
  }
})
