# ERAMS — System Diagrams

Diagrams are maintained as Mermaid source directly in this file (no separate image
export) so they render natively on GitHub, in VS Code (Markdown Preview Mermaid
Support extension), and in most Markdown viewers, and stay easy to update as the
system changes. For the final report / oral defense slides, open this file's
preview and export each rendered diagram as an image (e.g. right-click → Save
Image, or a screenshot of the rendered block).

Covers all 5 roles: Patient, Dispatcher, Ambulance Driver, Hospital Staff, Administrator.

---

## 1. DFD Level 0 — Context Diagram

ERAMS as a single process, showing every external entity and the three outbound
integrations (SMS, voice/video, DHIS2 export).

```mermaid
%%{init: {'theme': 'base', 'themeVariables': {'fontSize': '16px'}}}%%
flowchart TB
    Patient([Patient])
    Dispatcher([Dispatcher])
    Driver([Ambulance Driver])
    Hospital([Hospital Staff])
    Admin([Administrator])

    ERAMS[["ERAMS\nEmergency Response &\nAmbulance Management System"]]

    SMS[/Africa's Talking\nSMS Gateway/]
    Agora[/Agora\nVoice & Video/]
    DHIS2[/DHIS2\nHealth Information System/]

    Patient -- "request details, location,\nrating, chat/call" --> ERAMS
    ERAMS -- "nearby ambulances, trip status,\nETA, driver info, chat/call" --> Patient

    Dispatcher -- "incident data, manual\ndispatch, status overrides" --> ERAMS
    ERAMS -- "live map, incident list,\nfleet status" --> Dispatcher

    Driver -- "GPS location, status\nupdates, accept/decline" --> ERAMS
    ERAMS -- "job offers, incident details,\nnavigation data" --> Driver

    Hospital -- "acknowledgement" --> ERAMS
    ERAMS -- "incoming patient alert,\nlive ETA" --> Hospital

    Admin -- "fleet/user/hospital\nCRUD, analytics queries" --> ERAMS
    ERAMS -- "analytics, reports,\nuser & fleet records" --> Admin

    ERAMS -- "SMS notifications" --> SMS
    ERAMS <-- "call/video session" --> Agora
    ERAMS -- "aggregated incident data" --> DHIS2

    style ERAMS fill:#c0392b,stroke:#7b241c,color:#fff,stroke-width:2px
```

---

## 2. DFD Level 1 — System Decomposition

Breaks ERAMS into its 10 major processes and 7 data stores.

```mermaid
%%{init: {'theme': 'base', 'themeVariables': {'fontSize': '15px'}}}%%
flowchart TB
    Patient([Patient])
    Dispatcher([Dispatcher])
    Driver([Ambulance Driver])
    Hospital([Hospital Staff])
    Admin([Administrator])

    P1["1.0\nAuthenticate &\nRoute by Role"]
    P2["2.0\nLog / Request\nIncident"]
    P3["3.0\nDispatch\n(auto PostGIS +\nmanual override)"]
    P4["4.0\nAccept / Decline\nJob Offer"]
    P5["5.0\nTrack Trip &\nUpdate Status"]
    P6["6.0\nCommunicate\n(chat, voice, video)"]
    P7["7.0\nRate & Close\nTrip"]
    P8["8.0\nNotify\n(SMS)"]
    P9["9.0\nManage Fleet,\nUsers, Hospitals"]
    P10["10.0\nAnalytics &\nDHIS2 Export"]

    DS1[(profiles)]
    DS2[(ambulances)]
    DS3[(incidents)]
    DS4[(trips)]
    DS5[(messages)]
    DS6[(hospitals)]
    DS7[(incident_events)]

    Patient --> P1
    Dispatcher --> P1
    Driver --> P1
    Hospital --> P1
    Admin --> P1
    P1 <--> DS1

    Patient -- "emergency type,\nlocation, photo" --> P2
    Dispatcher -- "incident details" --> P2
    P2 --> DS3
    P2 --> P3

    P3 <--> DS2
    P3 <--> DS3
    P3 -- "job offer" --> P4
    P3 --> P8

    Driver -- "accept / decline" --> P4
    P4 <--> DS3
    P4 <--> DS4
    P4 --> P8
    P4 -. "re-offer on decline" .-> P3

    Driver -- "GPS + status" --> P5
    Dispatcher -- "manual status" --> P5
    P5 <--> DS2
    P5 <--> DS3
    P5 --> DS7
    P5 --> P8
    P5 -- "live position, ETA" --> Patient
    P5 -- "live position, ETA" --> Hospital
    P5 -- "live position, ETA" --> Dispatcher

    Patient <--> P6
    Driver <--> P6
    Dispatcher <--> P6
    P6 <--> DS5

    Patient -- "star rating" --> P7
    P7 --> DS4
    P7 -- "recompute rating" --> DS2

    P8 -- "SMS" --> Driver
    P8 -- "SMS" --> Patient
    P8 -- "SMS" --> Hospital
    P8 --> DS7

    Admin -- "CRUD" --> P9
    P9 <--> DS1
    P9 <--> DS2
    P9 <--> DS6

    Admin -- "report request" --> P10
    P10 <--> DS3
    P10 <--> DS4
    P10 -- "export" --> P10
```

---

## 3. UML Use Case Diagram (all 5 roles)

Mermaid has no native use-case notation, so actors and use cases are modeled as a
flowchart: actors on the outside, use-case ovals inside the system boundary,
association lines showing which role performs which use case.

```mermaid
%%{init: {'theme': 'base', 'themeVariables': {'fontSize': '14px'}}}%%
flowchart LR
    Patient([Patient])
    Dispatcher([Dispatcher])
    Driver([Ambulance Driver])
    Hospital([Hospital Staff])
    Admin([Administrator])

    subgraph SYS["ERAMS System Boundary"]
        direction TB

        UC1((Register / Login))
        UC2((View Nearby Ambulances))
        UC3((Request Ambulance))
        UC4((Track Trip Live))
        UC5((Chat with Driver))
        UC6((Voice / Video Call))
        UC7((Rate Trip))

        UC8((Log Incident Manually))
        UC9((Auto-Dispatch Nearest))
        UC10((Manual Dispatch Override))
        UC11((View Live Fleet Map))
        UC12((View Incident History))

        UC13((Accept / Decline Job))
        UC14((Update GPS Location))
        UC15((Update Trip Status))
        UC16((Navigate to Scene))

        UC17((Acknowledge Incoming Patient))
        UC18((View Live ETA))

        UC19((Manage Fleet))
        UC20((Manage Users))
        UC21((Manage Hospitals))
        UC22((View Analytics))
        UC23((Export to DHIS2))
    end

    Patient --- UC1
    Patient --- UC2
    Patient --- UC3
    Patient --- UC4
    Patient --- UC5
    Patient --- UC6
    Patient --- UC7

    UC3 -. include .-> UC9

    Dispatcher --- UC1
    Dispatcher --- UC8
    Dispatcher --- UC9
    Dispatcher --- UC10
    Dispatcher --- UC11
    Dispatcher --- UC12
    Dispatcher --- UC5

    Driver --- UC1
    Driver --- UC13
    Driver --- UC14
    Driver --- UC15
    Driver --- UC16
    Driver --- UC5
    Driver --- UC6
    Driver --- UC12

    Hospital --- UC1
    Hospital --- UC17
    Hospital --- UC18
    Hospital --- UC12

    Admin --- UC1
    Admin --- UC19
    Admin --- UC20
    Admin --- UC21
    Admin --- UC22
    Admin --- UC23
```

---

## 4. Sequence Diagram — Patient Booking Flow

Covers Phases 10–13 and 15–16: request → nearest-driver offer → accept/decline
(with re-offer) → live tracking → arrival → completion → rating, with SMS
notifications at each milestone.

```mermaid
%%{init: {'theme': 'base', 'themeVariables': {'fontSize': '14px'}}}%%
sequenceDiagram
    actor P as Patient
    participant App as Flutter App
    participant DB as Supabase (Postgres + RPC)
    actor D as Driver
    participant SMS as Africa's Talking

    P->>App: Open patient home (GPS location)
    App->>DB: nearby_ambulances(lat, lng)
    DB-->>App: ranked ambulance list (distance, fare, rating)
    App-->>P: show map + ranked cards

    P->>App: Fill request form (type, notes, photo)
    P->>App: Select ambulance
    App->>DB: createPatientIncident()
    DB->>DB: dispatch_incident(p_patient_id, ambulance)
    DB-->>App: incident created, status = pending_acceptance
    App->>SMS: notifyDriverJobOffer()
    SMS-->>D: SMS: new job offer

    App-->>P: navigate to trip tracking (waiting)
    DB-->>D: Realtime: job offer card (30s countdown)

    alt Driver accepts within 30s
        D->>App: acceptTrip(incidentId)
        App->>DB: accept_trip RPC
        DB-->>App: status = dispatched
        App->>SMS: notifyPatientDriverAccepted()
        SMS-->>P: SMS: driver accepted, ETA
        DB-->>P: Realtime: tracking screen updates (driver name, map)
    else Driver declines or countdown expires
        D->>App: declineTrip(incidentId) / timeout
        App->>DB: decline_trip RPC (re-offer nearest next driver)
        DB-->>App: next_ambulance_id
        App->>SMS: notifyDriverJobOffer() [next driver]
        Note over DB,D: repeats until accepted or no ambulance available
    end

    D->>App: "I'm En Route" -> "I've Arrived"
    App->>DB: update_incident_status RPC
    DB-->>P: Realtime: map + ETA + status banner update
    App->>SMS: notifyPatientDriverArrived()
    SMS-->>P: SMS: ambulance has arrived

    D->>App: "Incident Complete"
    App->>DB: update_incident_status(completed)
    DB-->>P: Realtime: completion dialog (duration, fare)
    P->>App: Rate trip (1-5 stars) or Skip
    App->>DB: submitRating()
    DB->>DB: trigger: recompute ambulances.rating
```

---

## 5. Sequence Diagram — Payment Flow (Planned, Phase 14)

**Not yet implemented.** Phase 14 (Flutterwave mobile money) is deferred by team
decision as of 3 Jul 2026 — every other patient-portal phase is complete, so this
is documented as the intended design for the final report, not shipped behavior.

```mermaid
%%{init: {'theme': 'base', 'themeVariables': {'fontSize': '14px'}}}%%
sequenceDiagram
    actor P as Patient
    participant App as Flutter App
    participant FW as Flutterwave API
    participant DB as Supabase (Postgres + Edge Function)
    actor D as Driver

    P->>App: Select ambulance, choose payment method
    alt MTN MoMo / Airtel Money
        App->>FW: Charge request (phone, amount)
        FW-->>P: USSD/PIN prompt on phone
        P->>FW: Approve payment
        FW->>DB: Webhook: payment success/failure
        DB->>DB: verify signature, update trips.payment_status
    else Card payment
        App->>FW: Inline checkout (WebView)
        FW-->>App: 3-D Secure / OTP challenge
        P->>App: Complete challenge
        FW->>DB: Webhook: payment success/failure
    else Cash
        App->>DB: Set payment_method = 'cash', payment_status = 'pending'
        Note over App,DB: No external call; proceeds immediately
    end

    DB-->>App: payment_status = paid (or cash pending)
    App->>DB: createPatientIncident() / dispatch_incident RPC
    DB-->>D: job offer (as in booking flow)

    opt Cash trips only
        D->>App: Confirm "cash received" at trip completion
        App->>DB: update trips.payment_status = 'cash_received'
    end
```

---

## 6. Sequence Diagram — Dispatcher-Initiated Flow

Covers Phases 2–7: the original telephone-in / dispatcher-logs-on-behalf-of-caller
flow, still fully supported alongside the patient-initiated flow above.

```mermaid
%%{init: {'theme': 'base', 'themeVariables': {'fontSize': '14px'}}}%%
sequenceDiagram
    actor Disp as Dispatcher
    participant App as Flutter App
    participant DB as Supabase (Postgres + RPC)
    actor D as Driver
    actor H as Hospital Staff
    participant SMS as Africa's Talking

    Disp->>App: New Incident form (pin location, type, notes, hospital)
    App->>DB: IncidentService.createIncident()
    DB-->>App: incident row created, status = logged
    DB-->>Disp: Realtime: card + map marker appear

    Disp->>App: Click "Dispatch Nearest"
    App->>DB: dispatch_incident RPC (no p_patient_id)
    DB->>DB: ST_Distance nearest available ambulance
    alt Ambulance found
        DB-->>App: assigned_ambulance_id set, status = dispatched
        App->>SMS: notifyHospitalIncomingPatient()
        SMS-->>H: SMS: incoming patient + ETA
        DB-->>D: Realtime: incident alert (no accept/decline; dispatcher-assigned)
    else No ambulance available
        DB-->>App: error: no_ambulance_available
        App-->>Disp: red banner + "Manual" fallback button
        Disp->>App: Manual dispatch (pick ambulance from ranked list)
        App->>DB: dispatch_incident RPC (p_ambulance_id override)
        DB-->>App: assigned_ambulance_id set, status = dispatched
    end

    D->>App: "I'm En Route"
    App->>DB: update_incident_status RPC
    DB-->>Disp: Realtime: card + marker update (blue)
    DB-->>H: Realtime: ETA updates as ambulance GPS moves

    H->>App: "Acknowledge - Ready to Receive"
    App->>DB: acknowledgeIncident() -> incident_events row

    D->>App: "I've Arrived" -> "Incident Complete"
    App->>DB: update_incident_status RPC (arrived, then completed)
    DB-->>Disp: incident removed from active list, appears in History
    DB-->>Disp: Admin analytics: response time recorded (created_at -> arrived_at)
```
