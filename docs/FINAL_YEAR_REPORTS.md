**KYAMBOGO**![](md_output/media/image1.png){width="1.5520833333333333in" height="1.2395833333333333in"} **UNIVERSITY**

**SCHOOL OF COMPUTING AND INFORMATION SCIENCE**

**DEPARTMENT OF INFORMATION TECHNOLOGY**

**EMERGENCY RESPONSE AND AMBULANCE MANAGEMENT SYSTEM (ERAMS)**

**BY**

**ASHABA RITAH: *23/U/ITE/04352/PE***

**KATUSIIME EUGENE*: 23/U/ITE/06654/PE***

**OCHIRIA ELIAS ONYAIT*: 23/U/ITD/14569/PD***

**ASHAKA JOSEPH: *23/U/ITE/04363/PE***

**A Final Year Project Report Submitted to the School of Computing and Information Science in Partial Fulfillment of the Requirements for the Award of the Degree of Bachelor of Information Technology and Computing of Kyambogo University.**

**Supervisor: *MADAM AHIBISIBWE SHALLON***

**July 2026**

**\
**

**DECLARATION**

We declare that the work presented in this research project is our original work and has not been submitted to any University or Institution of Higher Learning for any academic award. All work from other authors has been fully and properly acknowledged and cited.

Signature: \...\...\...\...\...\...\...\...\...\...\...\...\...\...\... Date: \...\...\...\...\...\...\...\...\...\...\...

**ASHABA RITAH**

(Researcher)

Signature: \...\...\...\...\...\...\...\...\...\...\...\...\...\...\... Date: \...\...\...\...\...\...\...\...\...\...\...

**OCHIRIA ELIAS ONYAIT**

(Researcher)

Signature: \...\...\...\...\...\...\...\...\...\...\...\...\...\...\... Date: \...\...\...\...\...\...\...\...\...\...\...

**KATUSIIME EUGENE**

(Researcher)

Signature: \...\...\...\...\...\...\...\...\...\...\...\...\...\...\... Date: \...\...\...\...\...\...\...\...\...\...\...

**ASHAKA JOSEPH**

(Researcher)

Signature: \...\...\...\...\...\...\...\...\...\...\...\...\...\..... Date: \...\...\...\...\...\...\...\...\...\...\...

**Ms. Shallon Ahimbisibwe**

(Supervisor)

**APPROVAL**

This is to certify that this research project titled: **\"An Emergency Response and Ambulance Management System (ERAMS)\"** has been carried out under my/our supervision and is now ready for submission to the Examinations Board and Senate of Kyambogo University.

Signature: \...\...\...\...\...\...\...\...\...\...\...\...\...\..... Date: \...\...\...\...\...\...\...\...\...\...\...

**Ms. Shallon Ahimbisibwe**

(Supervisor)

**\
**

**DEDICATION**

This research project is dedicated to our families and mentors whose unwavering support, encouragement, and sacrifices have made our academic journey possible. We also dedicate this work to the patients and healthcare workers of Uganda, whose need for timely emergency medical services inspired this study.

**ACKNOWLEDGEMENT**

We wish to express our sincere gratitude to our supervisor, Ms. Shallon Ahimbisibwe, for her invaluable guidance, constructive feedback, and continuous support throughout the development of this research project. Her expertise and dedication have greatly shaped the direction and quality of this work.

We are equally grateful to the staff of Healthstone Hospital, Banda, and Mulago National Referral Hospital, who generously participated in our questionnaires and provided candid responses that informed the analysis presented in this proposal. Their practical insights into emergency response operations at both private and public sector facilities have been instrumental in grounding our research in real-world context across Uganda\'s diverse healthcare landscape.

We also thank the Department of Computer Science, School of Computing and Information Science, Kyambogo University, for providing an enabling academic environment. Finally, we acknowledge the support of our fellow students and all individuals who contributed in any way to the completion of this work.

**ABSTRACT**

The Emergency Response and Ambulance Management System (ERAMS) is a web-based application designed to improve the efficiency and effectiveness of emergency medical response services. Traditional emergency response processes often rely on manual communication methods, which can result in delayed ambulance dispatch, poor coordination among stakeholders, and difficulties in tracking emergency incidents. ERAMS addresses these challenges by providing a centralized platform for reporting emergencies, managing ambulance dispatch operations, and coordinating communication between dispatchers, ambulance drivers, and hospitals.

The system enables dispatchers to log emergency incidents, assign available ambulances, monitor incident status, and direct patients to appropriate hospitals. Ambulance drivers can receive assigned incidents and update their status during emergency response operations. Hospitals can access relevant incident information to prepare for incoming patients. The system also supports real-time location management and maintains comprehensive records of incidents and response activities.

The project was developed using modern web technologies and a relational database management system. The database design incorporates geospatial capabilities to support location-based operations and ambulance tracking. Various testing procedures were conducted to ensure the functionality, reliability, and usability of the system.

The implementation of ERAMS is expected to improve emergency response times, enhance coordination among emergency service providers, and facilitate efficient management of ambulance resources. Future enhancements may include mobile applications, GPS-based live tracking, SMS notifications, and intelligent ambulance routing.

**TABLE OF CONTENTS**

**DECLARATION \...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\... i**

**APPROVAL \...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\.... ii**

**DEDICATION \...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\.... iii**

**ACKNOWLEDGEMENTS \...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\..... iv**

**ABSTRACT \...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\..... v**

**LIST OF FIGURES \...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\.... vi**

**LIST OF TABLES \...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\..... vii**

**LIST OF ABBREVIATIONS \...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\..... viii**

# CHAPTER ONE: INTRODUCTION \...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\..... 1

## 1.0 Introduction \...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\... 1

## 1.1 Background of the Study \...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\.... 2

## 1.2 Problem Statement \...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\.... 3

## 1.3 General Objective \...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\..... 4

## 1.4 Specific Objectives \...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\... 4

## 1.5 Scope of the Study \...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\.... 5

## 1.6 Significance of the Study \...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\..... 5

# CHAPTER TWO: SYSTEM ANALYSIS \...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\.....6

## 2.0 Introduction \...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\..... 6

## 2.1 Existing System \...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\..... 6

## 2.2 Limitations of the Existing System \...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\... 7

###  2.2.1 Delayed Response Time \...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\.... 7

###  2.2.2 Poor Coordination \...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\... 7

###  2.2.3 Lack of Real-Time Tracking \...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...8

###  2.2.4 Inaccurate Record Management \...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\....8

###  2.2.5 Limited Reporting Capabilities \...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\.....8

## 2.3 Proposed System \...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\..... 9

## 2.4 Advantages of the Proposed System \...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\.....10

###  2.4.1 Faster Emergency Response \...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\.....10

###  2.4.2 Improved Coordination \...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\....10

###  2.4.3 Better Resource Utilization \...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...10

###  2.4.4 Enhanced Data Management \...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\....11

###  2.4.5 Improved Decision Making \...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...11

## 2.5 Feasibility Study \...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\....11

###  2.5.1 Technical Feasibility \...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...11

###  2.5.2 Economic Feasibility \...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\.....12

###  2.5.3 Operational Feasibility \...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\.... 12

###  2.5.4 Schedule Feasibility \...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\....12

# CHAPTER THREE: SYSTEM REQUIREMENTS \...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...13

## 3.0 Introduction \...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\.... 13

## 3.1 Functional Requirements \...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\..... 13

## 3.2 Non-Functional Requirements \...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...15

## 3.3 User Requirements \...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\..... 16

###  3.3.1 Dispatcher \...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\....16

###  3.3.2 Ambulance Driver \...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\.....16

###  3.3.3 Hospital Staff \...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\.....17

###  3.3.4 Administrator \...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\.... 17

## 3.4 Hardware Requirements \...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\....18

## 3.5 Software Requirements \...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\.... 18

## 3.6 System Constraints \...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\.... 19

# CHAPTER FOUR: SYSTEM DESIGN \...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\..... 20

## 4.0 Introduction \...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\... 20

## 4.1 System Architecture \...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\..... 20

## 4.2 Use Case Diagram \...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\.... 21

## 4.3 Data Model (ERD) \...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\... 22

## 4.4 Activity Diagram \...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\... 26

## 4.5 Sequence Diagram \...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\....27

# CHAPTER FIVE: SYSTEM IMPLEMENTATION AND TESTING \...\...\...\...\...\...\...\...\...\..... 28

## 5.0 Database Design \...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\... 28

## 5.1 Implementation Notes \...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\... 28

## 5.2 RLS Policy Summary \...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\.... 29

## 5.3 Relationship Summary \...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...30

## 5.4 System Implementation \...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\.... 31

## 5.5 Features Implemented \...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\... 32

## 5.6 System Testing \...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\..... 34

## 5.7 Testing Approach \...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\.... 34

# CHAPTER SIX: CONCLUSION AND RECOMMENDATIONS \...\...\...\...\...\...\...\...\...\...\..... 36

## 6.0 Introduction \...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\..... 36

## 6.1 Conclusion \...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\... 36

## 6.2 Recommendations \...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\... 37

## 6.3 Final Remarks \...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\..... 39

## REFERENCES \...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\.... 40

## APPENDICES \...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\...\.... 42

**LIST OF TABLES**

[Table 3.4 Hardware Requirements [9](#_Toc235522857)](#_Toc235522857)

[Table 3.5 Software Requirements [10](#_Toc235522858)](#_Toc235522858)

[Table 4.2.1 Profiles Entity Attributes [15](#_Toc235522859)](#_Toc235522859)

[Table 4.2.2 Hospitals Entity Attributes [15](#_Toc235522860)](#_Toc235522860)

[Table 4.2.3 Ambulances Entity Attributes [16](#_Toc235522861)](#_Toc235522861)

[Table 4.2.4 Incident Entity Attributes [17](#_Toc235522862)](#_Toc235522862)

[Table 4.2.5 Incident Events Entry Attributes [17](#_Toc235522863)](#_Toc235522863)

**\
LIST OF ACRONYMS**

  --------------- -------------------------------------------------------
  **API**         Application Programming Interface

  **DHIS2**       District Health Information Software 2

  **EMS**         Emergency Medical Services

  **ERAMS**       Emergency Response and Ambulance Management System

  **GIS**         Geographic Information System

  **GPS**         Global Positioning System

  **ICT**         Information and Communication Technology

  **MoH**         Ministry of Health

  **NHSE**        National Health Service England

  **SDLC**        Systems Development Life Cycle

  **SMS**         Short Message Service

  **SQL**         Structured Query Language

  **UI**          User Interface

  **UML**         Unified Modelling Language

  **URSA**        Uganda Road Safety Authority

  **WHO**         World Health Organization
  --------------- -------------------------------------------------------

**CHAPTER ONE: INTRODUCTION**

**1.0 Introduction**

Emergency medical services play a critical role in saving lives by providing timely medical assistance and transportation to healthcare facilities during emergencies. However, many emergency response systems still rely on manual processes such as phone calls, paper records, and limited coordination between dispatch centres, ambulance drivers, and hospitals. These challenges often lead to delayed response times and inefficient utilization of available resources.

The Emergency Response and Ambulance Management System (ERAMS) is a web-based platform developed to improve the management of emergency incidents and ambulance dispatch operations. The system provides a centralized environment where dispatchers can record incidents, assign ambulances, monitor emergency response activities, and coordinate with hospitals. By automating these processes, ERAMS aims to enhance efficiency, reduce response times, and improve the quality of emergency medical services.

**1.1 Background of the Study**

The increasing demand for emergency medical services has highlighted the need for efficient systems that can support rapid response and effective coordination among emergency service providers. Traditional methods of managing ambulance services often involve manual communication channels, which can result in delays, miscommunication, and poor record management.

Advancements in information technology have enabled the development of digital systems that improve communication, data management, and decision-making processes. Emergency Response and Ambulance Management Systems have emerged as important tools for managing emergency incidents, tracking ambulance movements, and coordinating healthcare resources. ERAMS is designed to leverage these technological advancements to provide an efficient and reliable solution for emergency response management.

**1.2 Problem Statement**

**Traditional emergency response at the case study sites (Health stone Hospital, Banda, and Mulago National Referral Hospital) relies heavily on manual communication --- telephone calls and paper or DHIS2 logbooks. This leads to delayed response times (often exceeding one hour at Mulago), miscommunication, no real-time visibility into ambulance location or availability, and no structured record of incident outcomes for performance review.**

**1.3 General Objective**

To develop a web-based Emergency Response and Ambulance Management System that improves emergency incident management, ambulance dispatch operations, and coordination among emergency response stakeholders.

**1.4 Specific Objectives**

1.  To develop a system for recording and managing emergency incidents.

2.  To automate ambulance assignment and dispatch operations.

3.  To facilitate communication between dispatchers, ambulance drivers, and hospitals.

4.  To provide real-time tracking and monitoring of emergency response activities.

5.  To maintain accurate records of incidents and ambulance operations.

**1.5 Scope of the Study**

The scope of ERAMS focuses on the management of emergency incidents and ambulance dispatch services. The system supports emergency incident reporting, ambulance assignment, hospital coordination, incident tracking, and management of emergency response records.

The system is intended for use by dispatchers, ambulance drivers, hospital staff, and administrators. Features outside emergency response operations, such as hospital patient management and financial management, are beyond the scope of this project.

**1.6 Significance of the Study**

The implementation of ERAMS is expected to provide several benefits:

-   Improved emergency response times through automated dispatch procedures.

-   Enhanced coordination among dispatchers, ambulance drivers, and hospitals.

-   Better utilization of ambulance resources.

-   Improved record keeping and incident management.

**CHAPTER TWO: SYSTEM ANALYSIS**

**2.0 Introduction**

System analysis is a critical phase in system development that involves examining the existing system, identifying its weaknesses, and determining the requirements for the proposed system. This chapter analyses the current emergency response and ambulance management process, identifies the challenges associated with the existing system, and presents the proposed solution, namely the Emergency Response and Ambulance Management System (ERAMS).

**2.1 Existing System**

In many emergency response organizations, ambulance dispatch and incident management processes are performed manually. Emergency incidents are typically reported through telephone calls, after which dispatchers record incident details manually and communicate with ambulance drivers using phone calls or radio communication.

The existing system often relies on paper-based records and manual coordination between dispatch centres, ambulance drivers, and hospitals. Information sharing is usually slow and may lead to communication errors, delays in ambulance dispatch, and difficulties in tracking ongoing emergency operations.

Currently, emergency services at the case study sites depend on:

-   Phone calls / a toll-free line to request ambulances

-   Manual or DHIS2-based recording of patient and incident details

-   No real-time ambulance location tracking

**2.2 Limitations of the Existing System**

The current manual approach to emergency response management presents several challenges:

**2.2.1 Delayed Response Time**

Manual communication and dispatch procedures can cause delays in responding to emergency incidents.

**2.2.2 Poor Coordination**

Communication between dispatchers, ambulance drivers, and hospitals may not be well coordinated, leading to operational inefficiencies.

**2.2.3 Lack of Real-Time Tracking**

The existing system lacks mechanisms for monitoring ambulance locations and tracking incident progress in real time.

**2.2.4 Inaccurate Record Management**

Paper-based records are susceptible to loss, duplication, and human errors.

**2.2.5 Limited Reporting Capabilities**

Generating reports and analysing emergency response performance can be difficult due to scattered and manually maintained records.

**2.3 Proposed System**

The proposed Emergency Response and Ambulance Management System (ERAMS) is a web-based platform designed to automate and improve emergency response operations.

The system provides a centralized platform for managing emergency incidents, dispatching ambulances, monitoring ambulance activities, and coordinating communication among emergency response stakeholders.

ERAMS introduces a centralized, role-based system where:

-   Dispatchers can log an emergency call with location, nature of emergency, and patient notes, and dispatch the nearest available ambulance automatically (PostGIS geospatial query) or manually

-   Ambulance drivers receive dispatch alerts in real time, share live GPS location, advance the incident through status stages, and get a one-tap "Navigate to Scene" link into Google Maps

-   Hospital staff see incoming patients with a live ETA and can acknowledge readiness to receive

-   Administrators manage the ambulance fleet, manage user accounts (including creating new accounts and resetting passwords), and view response-time analytics

Key features of the proposed system include:

-   Digital incident reporting.

-   Ambulance assignment and dispatch management.

-   Hospital coordination and communication.

-   Real-time ambulance location management.

-   Incident status tracking.

-   Comprehensive reporting and record management.

**2.4 Advantages of the Proposed System**

The proposed ERAMS offers several advantages over the existing system:

**2.4.1 Faster Emergency Response**

Automation of dispatch operations reduces delays and improves response times.

**2.4.2 Improved Coordination**

The system facilitates effective communication among dispatchers, drivers, and hospitals.

**2.4.3 Better Resource Utilization**

Ambulances can be assigned efficiently based on availability and location.

**2.4.4 Enhanced Data Management**

Digital storage of records improves accuracy, accessibility, and security.

**2.4.5 Improved Decision Making**

Reports and analytics support management in evaluating system performance and making informed decisions.

**2.5 Feasibility Study**

A feasibility study was conducted to determine the viability of developing and implementing ERAMS.

**2.5.1 Technical Feasibility**

The technologies required for the development of ERAMS, including web development frameworks, database management systems, and geospatial technologies, are readily available and suitable for implementation.

**2.5.2 Economic Feasibility**

The proposed system is cost-effective compared to the operational inefficiencies and risks associated with manual emergency response management processes.

**2.5.3 Operational Feasibility**

The system is designed to be user-friendly and can be adopted by dispatchers, ambulance drivers, hospital staff, and administrators with minimal training.

**2.5.4 Schedule Feasibility**

The project can be completed within the planned development timeline using the available resources and development tools.

**CHAPTER THREE: SYSTEM REQUIREMENTS**

**3.0 Introduction**

This chapter defines the requirements for the Emergency Response and Ambulance Management System (ERAMS). System requirements describe what the system should do and the constraints under which it must operate. These requirements are divided into functional requirements, non-functional requirements, user requirements, hardware requirements, and software requirements.

**3.1 Functional Requirements**

**The system shall:**

-   **Allow user authentication with four distinct roles: Dispatcher, Ambulance Driver, Hospital Staff, Administrator --- each redirected to a role-specific dashboard on login**

-   **Allow dispatchers to log an emergency incident (location pin on a map, nature of emergency, reporter details, patient condition notes, target hospital)**

-   **Automatically assign the nearest available ambulance to an incident using geospatial distance (PostGIS ST_Distance), with a manual override/assignment dialog when no ambulance is available**

-   **Allow ambulance drivers to toggle their status (Available / Busy / Offline), receive a real-time alert when dispatched, advance an incident through its lifecycle (Dispatched → En Route → Arrived → Completed), and open turn-by-turn navigation to the incident location in Google Maps**

-   **Continuously broadcast the driver's live GPS location to the dispatcher's map and the receiving hospital's ETA display while an incident is active**

-   **Allow hospital staff to view incidents assigned to their hospital with a live, distance-based ETA, and acknowledge readiness to receive the patient (persisted, not lost on refresh)**

-   **Allow administrators to manage the ambulance fleet (add/edit ambulances, assign drivers and home hospitals), manage user accounts (create new accounts, edit name/phone, change role, reset a forgotten/compromised password), and view analytics (incident counts by status and by hospital, average response time)**

-   **Force any user with a newly created or admin-reset password to set their own password before reaching their dashboard**

-   **Provide each role with a profile view and a history tab of their own past incidents**

-   **Provide status, incident, and location updates in real time without requiring a manual page refresh**

**3.2 Non-Functional Requirements**

The system shall ensure:

-   **Security** --- authentication via Supabase Auth; every table protected by row-level security (RLS) policies scoped to role and ownership; no privileged credentials (service-role key) ever shipped to the client --- privileged operations (user creation, password reset) run server-side in Supabase Edge Functions

-   **Real-time responsiveness** --- incident, ambulance, and status changes propagate to all relevant roles via Supabase Realtime, typically within a few seconds

-   **Reliability and availability** --- backed by Supabase's managed Postgres and Firebase Hosting's CDN; failed driver location pushes are queued in memory and retried on reconnect

-   **Cross-platform usability** --- a single Flutter codebase serves the web (dispatcher/admin desktop use) and Android (driver mobile use) from one source tree

-   **Usability** --- role-appropriate, responsive layouts (desktop-oriented for dispatcher/admin, mobile-oriented for driver/hospital)

**3.3 User Requirements**

The system is designed for the following users:

**3.3.1 Dispatcher**

-   Manage emergency requests

-   Assign ambulances

-   Monitor incidents

**3.3.2 Ambulance Driver**

-   View assigned emergencies

-   Update status and location

**3.3.3 Hospital Staff**

-   Receive assigned emergency cases

-   Prepare for incoming patients

**3.3.4 Administrator**

-   Manage users and system data

-   Monitor system performance

**3.4 Hardware Requirements**

  -----------------------------------------------------------------------
  **Component**            **Minimum Requirement**
  ------------------------ ----------------------------------------------
  Processor                Intel Core i3 or higher

  RAM                      4 GB or more

  Storage                  20 GB free disk space

  Network                  Stable internet connection

  Device                   Computer or smartphone
  -----------------------------------------------------------------------

[]{#_Toc235522857 .anchor}Table 3.4 Hardware Requirements

**3.5 Software Requirements**

+---------------------------------------------------------------------------+
|   ----------------------------------------------------------------------- |
|   **Software**                  **Purpose**                               |
|   ----------------------------- ----------------------------------------- |
|   Operating System              Windows / Linux / macOS                   |
|                                                                           |
|   Code Editor                   Visual Studio Code                        |
|                                                                           |
|   Database                      PostgreSQL (Supa base)                    |
|                                                                           |
|   Backend                       PHP / Node.js (Supa base)                 |
|                                                                           |
|   Frontend                      Flutter, CSS, JavaScript                  |
|                                                                           |
|   Browser                       Chrome / Firefox                          |
|   ----------------------------------------------------------------------- |
+===========================================================================+
+---------------------------------------------------------------------------+

[]{#_Toc235522858 .anchor}Table 3.5 Software Requirements

**3.6 System Constraints**

1.  The system requires an internet connection to operate.

2.  The system depends on GPS or geolocation services for tracking.

3.  System performance may depend on network stability.

**CHAPTER FOUR: SYSTEM DESIGN**

**4.0 Introduction**

This chapter presents the design of the Emergency Response and Ambulance Management System (ERAMS). It describes how the system is structured and how its components interact to achieve the intended functionality. The design includes system architecture, use case diagram, data model (ERD), and system interaction diagrams.

**4.1 System Architecture**

The ERAMS system follows a **client-server architecture**, where the client interface communicates with the backend server, which in turn interacts with the database.

**System Components:**

-   **Frontend (Client Side):**\
    Developed using Flutter, CSS, and JavaScript. It provides the user interface for users, dispatchers, drivers, and hospital staff.

-   **Backend (Server Side):**\
    Handles business logic, authentication, request processing, and communication between frontend and database.

-   **Database Layer:**\
    Uses PostgreSQL (Supa base) to store and manage system data including users, incidents, ambulances, and hospitals.

**Architecture Flow:**

User → Frontend → Backend → Database → Backend → Frontend → User

![](md_output/media/image2.jpeg){width="6.268055555555556in" height="5.245138888888889in"}

**4.2 Use Case Diagram**

**Actors:**

-   **Dispatcher --- logs incidents, dispatches ambulances, monitors the live map and fleet**

-   **Ambulance Driver --- receives dispatch alerts, shares live location, updates incident status, navigates to the scene**

-   **Hospital Staff --- views incoming patients, monitors ETA, acknowledges incoming patients**

-   **Administrator --- manages the ambulance fleet, manages user accounts, views analytics**

**Main interactions:**

-   **Log incident → Dispatch ambulance (auto or manual) → Driver alerted → Driver navigates and updates status → Hospital notified with live ETA → Hospital acknowledges → Incident completed → Recorded in history and analytics**

**4.3 Data Model (ERD)**

**The ERAMS database is a relational model implemented in Supabase PostgreSQL with the PostGIS extension. It stores users, hospitals, ambulances, incidents, and incident events. PostGIS**

**geography (Point, 4326)**

**columns support real-time location tracking and nearest-ambulance geospatial queries.**

![](md_output/media/image3.jpeg){width="6.268055555555556in" height="8.136111111111111in"}

**Main Entities:**

1.  PROFILES: every system user (one row per auth. users' entry, auto created by a Postgres trigger on signup).

+---------------------------------------------------------------------------------+
| +-----------------+-----------------------------------------------------------+ |
| | > **Attribute** | > **Description**                                         | |
| +=================+===========================================================+ |
| | > id            | > Unique identifier for each user (matches auth.users.id) | |
| +-----------------+-----------------------------------------------------------+ |
| | > full_name     | > User's full name                                        | |
| +-----------------+-----------------------------------------------------------+ |
| | > email         | > User's sign-in email, kept in sync from auth.users      | |
| +-----------------+-----------------------------------------------------------+ |
| | > role          | > dispatcher \| driver \| hospital \| admin               | |
| +-----------------+-----------------------------------------------------------+ |
| | > hospital_id   | > Associated hospital (hospital-role users only)          | |
| +-----------------+-----------------------------------------------------------+ |
| | > phone         | > Contact number                                          | |
| +-----------------+-----------------------------------------------------------+ |
| | > created_at    | > Account creation timestamp                              | |
| +-----------------+-----------------------------------------------------------+ |
+=================================================================================+
+---------------------------------------------------------------------------------+

[]{#_Toc235522859 .anchor}Table 0.3 Profiles Entity Attributes

2.  HOSPITALS: registered hospitals.

+--------------------------------------------------------------------------+
| +-----------------------+----------------------------------------------+ |
| | > **Attribute**       | > **Description**                            | |
| +=======================+==============================================+ |
| | > id                  | > Hospital identifier                        | |
| +-----------------------+----------------------------------------------+ |
| | > name                | > Hospital name                              | |
| +-----------------------+----------------------------------------------+ |
| | > address             | > Physical address                           | |
| +-----------------------+----------------------------------------------+ |
| |                       |                                              | |
| +-----------------------+----------------------------------------------+ |
| | > location            | > GPS coordinates (PostGIS geography)        | |
| +-----------------------+----------------------------------------------+ |
| | > contact_phone       | > Hospital contact number                    | |
| +-----------------------+----------------------------------------------+ |
+==========================================================================+
+--------------------------------------------------------------------------+

[]{#_Toc235522860 .anchor}Table 4.3.2 Hospitals Entity Attributes

3.  AMBULANCES: fleet vehicles and their live tracking state.

+-------------------------------------------------------------------------------------------------+
| +------------------------+--------------------------------------------------------------------+ |
| | > **Attribute**        | > **Description**                                                  | |
| +========================+====================================================================+ |
| | > id                   | > Ambulance identifier                                             | |
| +------------------------+--------------------------------------------------------------------+ |
| | > plate_number         | > Registration number                                              | |
| +------------------------+--------------------------------------------------------------------+ |
| | > status               | > available \| dispatched \| en_route \| busy \| offline           | |
| +------------------------+--------------------------------------------------------------------+ |
| | > current_location     | > Live GPS location (PostGIS geography), updated by the driver app | |
| +------------------------+--------------------------------------------------------------------+ |
| | > driver_id            | > Assigned driver                                                  | |
| +------------------------+--------------------------------------------------------------------+ |
| | > hospital_id          | > Home base hospital                                               | |
| +------------------------+--------------------------------------------------------------------+ |
| | > last_location_update | > Timestamp of the last GPS push                                   | |
| +------------------------+--------------------------------------------------------------------+ |
+=================================================================================================+
+-------------------------------------------------------------------------------------------------+

[]{#_Toc235522861 .anchor}Table 4.3.3 Ambulances Entity Attributes

4.  INCIDENTS: emergency reports logged by dispatchers.

+----------------------------------------------------------------------------------------------------------------------------------------+
| +----------------------------------------------------------+-------------------------------------------------------------------------+ |
| | > **Attribute**                                          | > **Description**                                                       | |
| +==========================================================+=========================================================================+ |
| | > id                                                     | > Incident identifier                                                   | |
| +----------------------------------------------------------+-------------------------------------------------------------------------+ |
| | > reporter_name / reporter_phone                         | > Person reporting the emergency                                        | |
| +----------------------------------------------------------+-------------------------------------------------------------------------+ |
| | > incident_location                                      | > Emergency location (PostGIS geography)                                | |
| +----------------------------------------------------------+-------------------------------------------------------------------------+ |
| | > location_description                                   | > Free-text location detail                                             | |
| +----------------------------------------------------------+-------------------------------------------------------------------------+ |
| | > nature_of_emergency                                    | > Type of emergency                                                     | |
| +----------------------------------------------------------+-------------------------------------------------------------------------+ |
| | > patient_condition_notes                                | > Patient condition information                                         | |
| +----------------------------------------------------------+-------------------------------------------------------------------------+ |
| | > status                                                 | > logged \| dispatched \| en_route \| arrived \| completed \| cancelled | |
| +----------------------------------------------------------+-------------------------------------------------------------------------+ |
| | > created_by                                             | > Dispatcher who created the record                                     | |
| +----------------------------------------------------------+-------------------------------------------------------------------------+ |
| | > assigned_ambulance_id                                  | > Ambulance assigned by dispatch                                        | |
| +----------------------------------------------------------+-------------------------------------------------------------------------+ |
| | > assigned_hospital_id                                   | > Receiving hospital                                                    | |
| +----------------------------------------------------------+-------------------------------------------------------------------------+ |
| | > created_at / dispatched_at / arrived_at / completed_at | > Lifecycle timestamps, used to compute response time                   | |
| +----------------------------------------------------------+-------------------------------------------------------------------------+ |
+========================================================================================================================================+
+----------------------------------------------------------------------------------------------------------------------------------------+

[]{#_Toc235522862 .anchor}Table 4.3.4 Incident Entity Attributes

+--------------------------------------------------------------------------+
| +--------------------+-------------------------------------------------+ |
| | > **Attribute**    | > **Description**                               | |
| +====================+=================================================+ |
| | > id               | > Event identifier                              | |
| +--------------------+-------------------------------------------------+ |
| | > incident_id      | > Related incident                              | |
| +--------------------+-------------------------------------------------+ |
| | > event_type       | > status_change \| message \| location_ping     | |
| +--------------------+-------------------------------------------------+ |
| | > payload          | > Event details (free text / JSON)              | |
| +--------------------+-------------------------------------------------+ |
| | > actor_id         | > User who performed the action                 | |
| +--------------------+-------------------------------------------------+ |
| | > created_at       | > Event timestamp                               | |
| +--------------------+-------------------------------------------------+ |
+==========================================================================+
+--------------------------------------------------------------------------+

5.  INCIDENT_EVENTS: append-only audit log of activity on an incident (status changes, hospital acknowledgements, location pings).

[]{#_Toc235522863 .anchor}Table 4.3.5 Incident Events Entry Attributes

**Key Relationships:**

-   A hospital has many staff profiles

-   A hospital manages many ambulances

-   An ambulance is assigned to one driver

-   An incident is assigned to one ambulance

-   An incident has many events

**4.4 Activity Diagram**

The activity diagram shows the workflow of handling an emergency incident in the system:

**Process Flow:**

1.  User reports an emergency.

2.  Dispatcher receives the request.

3.  Dispatcher assigns an available ambulance.

4.  Ambulance driver receives notification.

5.  Driver travels to incident location.

6.  Hospital is notified.

7.  Incident is marked as completed.

**4.5 Sequence Diagram**

The sequence diagram illustrates interaction between system actors during an emergency response.

**Sequence Flow:**

-   User submits emergency request

-   System sends request to dispatcher

-   Dispatcher assigns ambulance

-   Ambulance driver accepts request

-   Driver updates status (en route → arrived → completed)

-   System updates hospital and records event

> ![](md_output/media/image4.jpeg){width="6.268055555555556in" height="6.102777777777778in"}

**CHAPTER FIVE: SYSTEM IMPLEMENTATION AND TESTING**

**5.0 Database Design**

**5.1 Implementation Notes**

**The schema in Section 4.3 is implemented as a series of numbered SQL migration files (supabase/migrations/), applied in order via the Supabase CLI:**

-   **Schema + PostGIS table creation, geography (Point, 4326) columns, and GIST spatial indexes on current_location / incident_location for fast nearest-ambulance queries**

```{=html}
<!-- -->
```
-   **Auth triggers** a SECURITY DEFINER Postgres function inserts a profiles row (full name, role, phone, email) automatically whenever a new auth. users' row is created, defaulting role to driver until an admin assigns the correct one

-   **Row-Level Security (RLS)** enabled on every table; no table is publicly readable or writable by default

5.2 RLS Policy Summary

+-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
|   --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|   **Role**     **profiles**                        **hospitals**     **ambulances**                            **incidents**                             **incident_events**                                |
|   ------------ ----------------------------------- ----------------- ----------------------------------------- ----------------------------------------- -------------------------------------------------- |
|   Dispatcher   read own; read-all via role check   read all          read all                                  full read/write                           insert                                             |
|                                                                                                                                                                                                             |
|   Driver       read own                            read all          read all; update own assigned ambulance   read/update own assigned incident         insert on own incident                             |
|                                                                                                                                                                                                             |
|   Hospital     read own                            read all          read all (for ETA)                        read incidents assigned to own hospital   insert (acknowledge) on own hospital's incidents   |
|                                                                                                                                                                                                             |
|   Admin        full read/write                     full read/write   full read/write                           full read/write                           full read                                          |
|   --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
+=============================================================================================================================================================================================================+
+-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+

Privileged operations that fall outside what RLS can safely express from the client creating a new auth. Users account and resetting a user's password are implemented as Supabase **Edge**

**Functions** (

admin_create_user, admin_reset_password). Each function independently re-verifies the caller's JWT and confirms profiles. Role = \'admin\' before using the service-role key, which never leaves the server.

5.3 Relationship Summary

Hospital

├── Profiles (Hospital Staff)

└── Ambulances

└── Driver (Profile)

Dispatcher (Profile)

└── Creates Incidents

├── Assigned Ambulance

├── Assigned Hospital

└── Incident Events

**6.0 System Implementation**

ERAMS is implemented as a **single Flutter codebase** targeting Web (primary dispatcher/admin/hospital demo target) and Android (driver), backed by **Supabase** and deployed to **Firebase Hosting**.

+--------------------------------------------------------------------------------------------------------------------------------------------------+
|   ---------------------------------------------------------------------------------------------------------------------------------------------- |
|   **Layer**           **Technology**                                                                                                             |
|   ------------------- -------------------------------------------------------------------------------------------------------------------------- |
|   Client              Flutter (Dart), single codebase for Web + Android                                                                          |
|                                                                                                                                                  |
|   State management    River pod (AsyncNotifier, Future Provider)                                                                                 |
|                                                                                                                                                  |
|   Routing             go_router, with role-based redirect guards                                                                                 |
|                                                                                                                                                  |
|   Maps                flutter_map + OpenStreetMap tiles (zero-cost, no API key)                                                                  |
|                                                                                                                                                  |
|   Driver navigation   Google Maps deep link (url_launcher) for turn-by-turn directions                                                           |
|                                                                                                                                                  |
|   GPS                 geolocator, periodic location push every 15 seconds                                                                        |
|                                                                                                                                                  |
|   Charts              fl_chart (admin analytics)                                                                                                 |
|                                                                                                                                                  |
|   Offline queueing    In-memory retry queue for failed GPS pushes, flushed on reconnect                                                          |
|                                                                                                                                                  |
|   Backend             Supabase (Postgres + PostGIS, Auth, Realtime, Edge Functions)                                                              |
|                                                                                                                                                  |
|   Server-side logic   Postgres RPC (dispatch incident, update_incident_status) + Deno Edge Functions (admin_create_user, admin_reset_password)   |
|                                                                                                                                                  |
|   Hosting             Firebase Hosting (static web build only)                                                                                   |
|                                                                                                                                                  |
|   CI/CD               GitHub Actions --- Flutter web build/deploy, Supabase migration/function deploy                                            |
|   ---------------------------------------------------------------------------------------------------------------------------------------------- |
+==================================================================================================================================================+
+--------------------------------------------------------------------------------------------------------------------------------------------------+

6.1 Features Implemented

-   **Authentication & RBAC**: email/password login via Supabase Auth, role-based dashboard redirects for four roles

-   **Dispatcher module**: incident logging form with map pin drop, live map (incident/ambulance/hospital markers), filterable incident dashboard, real-time updates

-   **Automated dispatch**: PostGIS nearest-available-ambulance RPC with manual-assignment fallback when no ambulance is available

-   **Driver module**: status toggle, real-time dispatch alerts, live GPS sharing every 15 seconds, status lifecycle controls, one-tap "Navigate to Scene" Google Maps deep link, offline GPS retry queue

-   **Hospital module**: incoming-patient list filtered to the user's hospital, live distance-based ETA, "Acknowledge: Ready to Receive" action persisted to the database (survives page refresh)

-   **Admin module**: fleet management (add/edit ambulances, assign drivers and home hospitals); user management (create accounts, edit name/phone, change role, reset passwords: all privileged actions routed through Edge Functions); analytics dashboard (incident counts by status/hospital, average response time)

-   **Account security**: newly created or password-reset accounts are flagged must_change_password and are required to set their own password before reaching their dashboard

-   **Profile & history**: every role has a profile view and a tab of their own incident history

-   **Cross-cutting**: responsive layouts per role, real-time propagation via Supabase Realtime throughout

**7.0 Testing**

**7.1 Testing Approach**

ERAMS testing combines automated static analysis with structured manual QA, rather than a separate automated test suite (given the compressed two-week build window):

-   **Static analysis**: flutter analyse is run after every development session and must report zero issues before a change is considered complete.

-   **Manual per-phase QA**: each build phase has an explicit "Needs Team Testing" checklist in [docs/COMPLETED_WORK.md](file:///C:\Users\Ritah\Desktop\project%20report\COMPLETED_WORK.md), covering the specific user actions and expected outcomes the team must walk through (e.g. "dispatch nearest ambulance and confirm both records update atomically," "acknowledge a patient and confirm it survives a page refresh")

-   **Cross-role, end-to-end smoke testing**: the full flow (dispatcher logs incident → auto-dispatch → driver alert → live GPS → hospital ETA → acknowledgement → completion → admin analytics) is walked through manually across simultaneous role sessions before a phase is marked verified

-   **Planned end-user evaluation**: a structured evaluation form (mirroring the original proposal's Section F: ease of use, GPS accuracy, dispatch speed, communication effectiveness) is administered during Phase 8 demo walkthroughs with representative users

**CHAPTER SIX: CONCLUSION AND RECOMMENDATIONS**

**6.0 Introduction**

This chapter presents the conclusion of the Emergency Response and Ambulance Management System (ERAMS) project and provides recommendations for further improvement and enhancement of the system. It summarizes the achievements of the project in relation to its objectives and evaluates its overall effectiveness in improving emergency response operations.

**6.1 Conclusion**

The Emergency Response and Ambulance Management System (ERAMS) was successfully designed and developed as a web-based platform aimed at improving the efficiency, coordination, and reliability of emergency medical response services.

The system addresses the major challenges associated with traditional emergency response mechanisms, which include delayed ambulance dispatch, poor communication between stakeholders, lack of real-time tracking, and inefficient record management. By introducing a centralized digital platform, ERAMS enables real-time incident reporting, automated ambulance dispatch, live GPS tracking, and structured communication between dispatchers, ambulance drivers, hospital staff, and administrators.

Through the implementation of geospatial technologies (PostGIS), real-time communication features, and a role-based access control system, ERAMS significantly improves the speed and accuracy of emergency response operations. The system also enhances transparency and accountability by maintaining detailed records of all emergency incidents and response activities.

The development process followed a structured software engineering approach, including system analysis, design, implementation, testing, and evaluation. The final system demonstrates that integrating modern web technologies and database systems can greatly improve emergency service delivery in healthcare environments.

Overall, ERAMS achieves its primary objective of improving emergency response efficiency and provides a scalable foundation for future digital healthcare emergency systems.

**6.2 Recommendations**

Although the system meets its core objectives, several improvements can be made to enhance its functionality, scalability, and usability in real-world deployment environments:

**6.2.1 Mobile Application Development**

A dedicated mobile application (especially for Android and iOS) should be developed for ambulance drivers and field responders to improve usability, reduce dependency on web interfaces, and support offline-first operations.

**6.2.2 Integration of SMS and USSD Services**

To support users without internet access, the system should integrate SMS and USSD-based emergency request features. This would ensure inclusivity, especially in rural or low-connectivity areas.

**6.2.3 Advanced GPS Tracking and Navigation**

Future versions of the system should integrate more advanced GPS tracking features, including:

-   Real-time traffic-aware routing

-   Predictive arrival time estimation

-   Automatic rerouting in case of road congestion or obstacles

**6.2.4 Artificial Intelligence-Based Dispatching**

The system can be enhanced with AI algorithms to improve ambulance assignment by considering factors such as:

-   Traffic conditions

-   Severity of emergency

-   Historical response patterns

-   Hospital capacity and availability

> **6.2.5 Integration with Hospital Information Systems**
>
> ERAMS should be integrated with hospital Electronic Health Record (EHR) systems to allow seamless sharing of patient information before arrival, enabling faster preparation and treatment.
>
> **6.2.6 System Scalability and Cloud Deployment**
>
> For large-scale deployment, the system should be hosted on a scalable cloud infrastructure with load balancing to handle high volumes of emergency requests without performance degradation.
>
> **6.2.7 Enhanced Security Measures**
>
> Although the current system implements authentication and role-based access control, additional security improvements are recommended:

-   Multi-factor authentication (MFA)

-   Enhanced audit logging

-   Encryption of sensitive medical and location data
