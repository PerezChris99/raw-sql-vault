# Raw SQL Vault — Master Index

**Phase:** 0 — Blueprint  
**Primary engine:** PostgreSQL 15+  
**Geographic priority:** Uganda, then worldwide  
**Index status:** Initial catalogue; each unit must be verified against the current legal/operational owner before implementation.

## 1. How to use this index

This is the stable inventory of planned database solution units. A slug identifies a **problem domain**, not a claim about the current legal name, mandate, existence, or independence of an institution. Organisation names, reporting lines, mandates, administrative boundaries, and operators can change. Record those changes as effective-dated reference data instead of renaming historical tables or silently reusing a slug.

- **Planned** means indexed, not implemented or production-approved.
- A project moves to **implemented** only after its schema, migrations, synthetic seed data, query catalogue, security model, tests, and documentation pass the acceptance gates in [ROADMAP.md](ROADMAP.md).
- Do not load production citizen, patient, taxpayer, student, financial, law-enforcement, refugee, land-title, or identity records into development fixtures.
- The index is a living catalogue, not a replacement for a legal mandate review or an authoritative government directory.

## 2. Uganda — central government, offices, and portfolios

The portfolio slugs below preserve the requested coverage. **Some listed portfolios may be administered through an office, minister of state, programme, or parent ministry rather than a separately constituted ministry.** Before building a solution, verify the current structure and represent the legal entity, parent, mandate, and effective dates explicitly.

Official starting points for that verification:
- [State House — Cabinet](https://statehouse.go.ug/the-cabinet/)
- [Parliament of Uganda — Cabinet members and Ministers of State](https://web.parliament.go.ug/page/cabinet-members-and-ministers-state)
- [Government Ministries of the Republic](https://mediacentre.go.ug/ministries)

| Stable slug | Coverage / capability | Typical database problems to investigate |
|---|---|---|
| `ug-op` | Office of the President | policy coordination records, decisions, action tracking, controlled reporting |
| `ug-opm` | Office of the Prime Minister | programme coordination, delivery monitoring, incident and inter-agency action registers |
| `ug-ovp` | Office of the Vice President | official correspondence, actions, programme reporting |
| `ug-state-house` | State House | administrative services, appointments, records, asset workflows |
| `ug-m-aaiif` | Agriculture, Animal Industry and Fisheries | extension services, livestock events, crop and fishery data, input distribution |
| `ug-m-defence-veterans` | Defence and Veteran Affairs | authorised asset, personnel-support, logistics and maintenance workflows; restrictive access |
| `ug-m-education-sports` | Education and Sports | school/facility registers, education statistics, grants, sports administration |
| `ug-m-energy-minerals` | Energy and Mineral Development | licence metadata, projects, energy assets, production and safety reporting |
| `ug-m-finance-planning` | Finance, Planning and Economic Development | budget versions, releases, commitments, expenditure and performance reporting |
| `ug-m-foreign-affairs` | Foreign Affairs | missions, correspondence, consular workflow and controlled records |
| `ug-m-gender-labour-social` | Gender, Labour and Social Development | labour services, social programmes, safeguarding and aggregate outcomes |
| `ug-m-health` | Health | facility capacity, aggregate HMIS, stock, service quality and referral workflows |
| `ug-m-internal-affairs` | Internal Affairs | lawful administrative workflow, immigration case metadata and controlled access |
| `ug-m-justice-constitutional` | Justice and Constitutional Affairs | legal opinions, case/workflow metadata, legislation and document retention |
| `ug-m-lands-housing-urban` | Lands, Housing and Urban Development | land records, parcel references, housing programmes, planning and dispute workflow |
| `ug-m-local-government` | Local Government | grants, service delivery, asset and work-order registers, local government reporting |
| `ug-m-public-service` | Public Service | establishment, HR transactions, training and performance administration |
| `ug-m-tourism-wildlife-antiquities` | Tourism, Wildlife and Antiquities | tourism statistics, permits, conservation monitoring and heritage inventories |
| `ug-m-trade-industry-coops` | Trade, Industry and Cooperatives | trade statistics, licensing, cooperative registry and market monitoring |
| `ug-m-water-environment` | Water and Environment | water assets, water-quality observations, permits and environmental monitoring |
| `ug-m-works-transport` | Works and Transport | roads, public works, transport safety, asset maintenance and service reliability |
| `ug-m-ict-national-guidance` | ICT and National Guidance | public ICT asset registers, service catalogue, approved data exchange and communications |
| `ug-m-kampala-metropolitan` | Kampala Capital City and Metropolitan Affairs | metropolitan service coordination and aggregate service measures |
| `ug-m-eac-affairs` | East African Community Affairs | regional commitments, meetings, action tracking and reporting |
| `ug-m-science-tech-innovation` | Science, Technology and Innovation portfolio | research grants, innovation programmes, intellectual-property metadata and outcomes |
| `ug-p-disaster-refugees` | Relief, Disaster Preparedness and Refugees portfolio | early-warning events, response logistics, referrals and humanitarian coordination |
| `ug-p-karamoja-affairs` | Karamoja Affairs portfolio | regional programme delivery and aggregate service-access reporting |
| `ug-p-northern-uganda` | Northern Uganda portfolio/programmes | regional recovery programme planning, budgets and outcomes |
| `ug-p-luweero-triangle` | Luweero Triangle portfolio/programmes | programme plans, disbursement controls and progress reporting |
| `ug-p-bunyoro-affairs` | Bunyoro Affairs portfolio/programmes | regional development programme tracking |
| `ug-p-teso-affairs` | Teso Affairs portfolio/programmes | regional development programme tracking |

## 3. Uganda — agencies, authorities, public bodies, and key institutions

The table is an initial operational inventory of requested and commonly relevant bodies, not a complete legal register of every public institution. Add each subsidiary, commission, authority, statutory body, agency, fund, and public corporation as a separate row when validated. Never assume an integration or data-sharing permission merely because two bodies appear in this index.

| Stable slug | Institution / capability | Candidate database solution |
|---|---|---|
| `ug-ura` | Uganda Revenue Authority | tax/customs workflow metadata, filing reconciliation, revenue analytics under strict controls |
| `ug-nira` | National Identification and Registration Authority | identity-service integration contracts and reconciliation metadata; no replicated national identity store by default |
| `ug-bou` | Bank of Uganda | supervised-institution reporting, payment-system metadata, monetary and financial aggregates |
| `ug-nssf` | National Social Security Fund | member contributions, claims processing, reconciliation and audit controls |
| `ug-ppda` | Public Procurement and Disposal of Public Assets Authority | procurement notices, awards, contract milestones and compliance analytics |
| `ug-ig` | Inspectorate of Government | authorised complaints/case workflow, evidence custody metadata and audit trail |
| `ug-upf` | Uganda Police Force | carefully restricted administrative records and evidence custody; no unconstrained mass-surveillance design |
| `ug-updf` | Uganda People's Defence Forces | authorised logistics and maintenance examples only; exclude operationally sensitive details |
| `ug-unra` | Uganda National Roads Authority / roads portfolio | road asset, inspection and works records; verify current institutional arrangements before implementation |
| `ug-nwsc` | National Water and Sewerage Corporation | billing reconciliation, service requests, network maintenance and aggregate reliability |
| `ug-umeme-legacy` | UMEME historical/provider transition data | legacy contract, meter, outage and handover reconciliation only where authorised |
| `ug-uedcl` | Uganda Electricity Distribution Company Limited | distribution asset, outage, metering and service workflows where within its remit |
| `ug-uegcl` | Uganda Electricity Generation Company Limited | generation assets, maintenance, dispatch and production reporting |
| `ug-nita-u` | National Information Technology Authority–Uganda | government ICT assets, standards compliance, approved integration and service monitoring |
| `ug-nema` | National Environment Management Authority | permits, environmental inspections, monitoring and remediation actions |
| `ug-unbs` | Uganda National Bureau of Standards | inspections, certifications, testing workflows and standards metadata |
| `ug-uia` | Uganda Investment Authority | investor services, project milestones and service-level reports |
| `ug-uepb` | Uganda Export Promotion Board | exporter services, market access and export promotion reporting |
| `ug-ec` | Electoral Commission | voter/election administration only within authorised workflows and disclosure rules |
| `ug-parliament` | Parliament of Uganda | bills, committee actions, questions, votes and document metadata |
| `ug-judiciary` | Judiciary / courts of judicature | court scheduling and case metadata with strict judicial confidentiality and role separation |
| `ug-kcca` | Kampala Capital City Authority | service requests, city assets, permits, works, finance and location references |
| `ug-ubos` | Uganda Bureau of Statistics | survey metadata, statistical releases, quality checks and controlled aggregates |
| `ug-ursb` | Uganda Registration Services Bureau | business/IP registration workflow and registry-quality reporting |
| `ug-ucc` | Uganda Communications Commission | operator/licence metadata, spectrum and aggregate sector reporting |
| `ug-nda` | National Drug Authority | product/establishment licences, inspection, batch and safety reporting |
| `ug-nms` | National Medical Stores | medicine procurement, batch inventory, expiry and delivery reconciliation |
| `ug-uneb` | Uganda National Examinations Board | examination administration, results controls and secure release workflow |
| `ug-ncdc` | National Curriculum Development Centre | curriculum/document versions and publication workflow |
| `ug-ucaa` | Uganda Civil Aviation Authority | aviation safety oversight and airport operational reporting |
| `ug-uwa` | Uganda Wildlife Authority | conservation assets, permits, patrol/admin records and wildlife statistics |
| `ug-ucda` | Uganda Coffee Development Authority | coffee traceability metadata, quality, market prices and export statistics |
| `ug-naro` | National Agricultural Research Organisation | research trials, germplasm metadata, sample provenance and findings |
| `ug-naads` | National Agricultural Advisory Services | extension programme delivery and input distribution controls |
| `ug-dairy-dev` | Dairy Development Authority | dairy quality, market, inspection and cold-chain data |
| `ug-urf` | Uganda Road Fund | road maintenance funding, allocations and expenditure reconciliation |
| `ug-dcic` | Directorate of Citizenship and Immigration Control | authorised immigration workflow metadata; minimise stored identity data |
| `ug-ups` | Uganda Prisons Service | tightly restricted health/service and facility-administration workflows |
| `ug-fia` | Financial Intelligence Authority | compliant case workflow and aggregate reporting under strict access controls |
| `ug-oag` | Office of the Auditor General | audit plans, findings, recommendations, evidence references and closure tracking |
| `ug-psc` | Public Service Commission | recruitment and appointment process metadata |
| `ug-hsc` | Health Service Commission | health workforce recruitment and service administration |
| `ug-esc` | Education Service Commission | education workforce recruitment and appointment process |
| `ug-nda-nms` | Shared pharmaceutical supply chain (cross-body) | interoperability and reconciliation layer only; keep each body's authority separate |

## 4. Uganda — local government and administrative geography

Treat geography as effective-dated reference data; names, boundaries, codes, jurisdictions and reporting structures change. A hierarchy must allow urban and rural variants instead of assuming one identical path for all places.

| Stable slug | Unit / level |
|---|---|
| `ug-lg-district` | District / district local government |
| `ug-lg-city` | City / city local government |
| `ug-lg-county` | County / county-level administrative reference where applicable |
| `ug-lg-municipality` | Municipality |
| `ug-lg-town-council` | Town council |
| `ug-lg-subcounty` | Sub-county |
| `ug-lg-city-division` | City division |
| `ug-lg-kcca-division` | KCCA division |
| `ug-lg-parish` | Parish |
| `ug-lg-village` | Village / lowest commonly used local administrative level |
| `ug-lg-ward` | Ward, where applicable |
| `ug-lg-local-service-zone` | Operational service area that may not equal a legal administrative boundary |

## 5. Uganda — public, private, NGO and civil-society sector catalogue

Each sector can include public and non-public implementations. The project owner must identify lawful data ownership, user groups, retention, disclosures, and whether records may be linked across organisations.

### Public service and governance

| Stable slug | Domain | Example problem |
|---|---|---|
| `ug-sector-public-service` | public administration | correspondence, workflow, assets, service requests, performance measures |
| `ug-sector-procurement` | procurement and contracts | requisition-to-payment, approvals, milestone and variation history |
| `ug-sector-public-finance` | budget and expenditure | budget versions, commitment controls, payment reconciliation |
| `ug-sector-tax-customs` | tax and customs | submission/assessment workflow and aggregate compliance measures |
| `ug-sector-identity-interoperability` | identity exchange | contract testing, consent/authority, matching outcomes and audit metadata |
| `ug-sector-elections` | elections | controlled election logistics and result-publication workflow |
| `ug-sector-justice` | legal and judicial services | filing, scheduling, chain of custody and retention |
| `ug-sector-local-government` | local service delivery | asset registers, work orders, budgets and resident requests |
| `ug-sector-land-registry` | land and property records | parcel references, title workflow, surveying evidence and disputes |
| `ug-sector-disaster-response` | disaster preparedness | incident register, tasking, supplies and response-time measurement |
| `ug-sector-immigration-border` | immigration and border operations | authorised case workflow and aggregate movement reporting |

### Social services and human development

| Stable slug | Domain | Example problem |
|---|---|---|
| `ug-sector-health-hmis` | health and HMIS | facility services, aggregate indicators, referrals and quality |
| `ug-sector-pharma-blood` | pharmacy and blood services | batch/expiry tracking, stock availability, cold chain |
| `ug-sector-health-insurance` | health financing and insurance | eligibility, claims workflow and reconciliation |
| `ug-sector-education-sis` | schools and education records | admissions, enrolment, attendance and transfers |
| `ug-sector-university-lms` | universities and e-learning | course registration, learning records and assessments |
| `ug-sector-examinations` | examinations and credentials | exam sessions, marking controls and secure publication |
| `ug-sector-labour-hr` | labour, HR and payroll | workforce administration, leave, payroll inputs and audit |
| `ug-sector-social-protection` | cash transfers and social assistance | eligibility workflow, payment reconciliation and appeals |
| `ug-sector-refugee-humanitarian` | refugee / displaced-person support | assistance inventory, referrals and aggregate delivery; strict confidentiality |
| `ug-sector-sports-culture` | sports, arts, culture and heritage | membership, events, grants, facilities and asset registers |
| `ug-sector-religious-orgs` | religious institutions | voluntary membership, donations and facility administration; privacy-first |

### Productive economy and infrastructure

| Stable slug | Domain | Example problem |
|---|---|---|
| `ug-sector-agriculture` | crops and farming | field records, input distribution, harvest and yield analysis |
| `ug-sector-livestock` | animal health and livestock | herd events, inspection, traceability and outbreak alerts |
| `ug-sector-fisheries` | fisheries and aquaculture | catch/effort records, licensing, quotas and lake safety |
| `ug-sector-cooperatives` | cooperatives | member accounts, produce deliveries, payments and reconciliation |
| `ug-sector-banking` | banking and payments | accounts, ledger, reconciliation, settlement and risk controls |
| `ug-sector-saccos-microfinance` | SACCOs and microfinance | savings, loans, repayments, approvals and statements |
| `ug-sector-mobile-money` | mobile-money systems | transaction reconciliation, reversals and fraud monitoring |
| `ug-sector-telecom-isps` | telecoms and ISPs | subscriptions, billing, outages and network capacity |
| `ug-sector-retail-fmcg` | retail, FMCG and market vendors | POS, stock movements, sales, margins and replenishment |
| `ug-sector-ecommerce` | e-commerce | catalogue, orders, payments, fulfilment and returns |
| `ug-sector-transport` | boda boda, taxi, bus, rail and air | scheduling, fleets, incidents and service reliability |
| `ug-sector-energy` | power, generation and distribution | assets, outages, maintenance and metering |
| `ug-sector-oil-gas-mining` | oil, gas and mining | permits, production, safety and environmental obligations |
| `ug-sector-water-sanitation` | water, sanitation and waste | asset maintenance, water quality, routes and service interruptions |
| `ug-sector-construction-real-estate` | construction and property | projects, permits, contracts, inspections and maintenance |
| `ug-sector-manufacturing` | manufacturing | work orders, quality inspection, traceability and inventory |
| `ug-sector-tourism-hospitality` | tourism, hotels and hospitality | bookings, occupancy, facilities and service quality |
| `ug-sector-media-broadcasting` | media and broadcasting | content catalogue, schedules, rights and distribution |
| `ug-sector-insurance-pensions` | insurance and pensions | policies, claims, contributions and actuarial source data |
| `ug-sector-ngos-donors` | NGOs, CBOs and donors | grants, budgets, activity plans, M&E and reporting |
| `ug-sector-fleet-fuel` | fleet and fuel | vehicle, trip, fuel, maintenance and exception records |
| `ug-sector-cybersecurity` | cyber/security operations | authorised assets, alerts, incidents and remediation |
| `ug-sector-sme-accounting` | SMEs and bookkeeping | invoices, expenses, receivables, payables and cash flow |
| `ug-sector-supply-chain` | supplier, warehouse and distribution | purchase orders, stock ledger, batch and delivery reconciliation |
| `ug-sector-data-quality` | data engineering and interoperability | imports, deduplication, quality, provenance and reconciliation |

## 6. Worldwide — universal solution domains

Worldwide units should use synthetic fixtures, internationalised identifiers and addresses, explicit currency/time-zone fields, localisation-ready text, and jurisdiction-specific policy adapters. Standards are integration targets, not automatic certification.

| Stable slug | Domain | Common backbone / candidate standards | SDGs commonly relevant |
|---|---|---|---|
| `ww-banking` | banking, accounts, payments and settlement | ledger, reconciliation, ISO 20022/SWIFT integration boundary | 1, 8, 9, 10, 16, 17 |
| `ww-insurance` | insurance, claims and actuarial data | policy/claim lifecycle, pricing assumptions and audit | 1, 3, 8, 10 |
| `ww-healthcare` | healthcare and clinical systems | HL7/FHIR-aligned exchange, ICD coding adapter, consent and provenance | 3, 9, 10 |
| `ww-pharmacy-supply` | pharmacy and medical supply | lot/serial, expiry, recall, cold-chain events | 3, 9, 12 |
| `ww-airlines-gds` | airlines, distribution systems and airports | itinerary, inventory, booking, ticketing and operational events | 8, 9, 13 |
| `ww-shipping-ports` | shipping, ports and customs | shipment/container events, manifests, clearance status | 8, 9, 14, 17 |
| `ww-warehouse-wms` | warehouse management | bins, lots, reservations, picking and reconciliation | 8, 9, 12 |
| `ww-transport-tms` | transport management | route, load, carrier, events, proof of delivery | 8, 9, 11, 13 |
| `ww-retail-pos` | retail, POS and loyalty | receipt, returns, price, stock ledger and customer consent | 8, 9, 12 |
| `ww-ecommerce-marketplace` | e-commerce and marketplaces | catalogue, seller, order, payment references and dispute workflow | 8, 9, 12 |
| `ww-social-platform` | social/content platforms | content metadata, moderation workflow, abuse reports and controls | 3, 5, 10, 16 |
| `ww-streaming-media` | streaming catalogues | content rights, catalogue, subscription, playback telemetry | 8, 9, 12 |
| `ww-ridehail-delivery` | ride-hailing and delivery | dispatch, assignment, pricing, status and safety incident records | 8, 9, 11 |
| `ww-hr-payroll` | HR and payroll | effective-dated workforce, leave, approvals and payroll exports | 5, 8, 10 |
| `ww-ats-lms` | applicant tracking and learning systems | recruitment stages, learning catalogue and credentials | 4, 5, 8, 10 |
| `ww-crm-marketing` | CRM and marketing automation | customer consent, campaign attribution and opt-out processing | 8, 9, 12 |
| `ww-erp-finance` | ERP finance | general ledger, periods, approval chains and reconciliations | 8, 9, 12, 16 |
| `ww-erp-procurement` | ERP procurement | sourcing, purchase orders, receipts, invoices and approvals | 8, 9, 12, 16 |
| `ww-erp-manufacturing` | ERP manufacturing | bills of materials, work orders, yield and quality | 8, 9, 12 |
| `ww-education-sis` | student information systems | enrolment, terms, assessment and academic history | 4, 5, 10 |
| `ww-mooc-lms` | MOOC and e-learning | course content, enrolment, events and credentialing | 4, 8, 9, 10 |
| `ww-egovernment` | digital government | permits, tax, licensing, case workflow and records | 9, 10, 16, 17 |
| `ww-census-statistics` | census and official statistics | sampling frames, collection status, disclosure control | 1, 3, 4, 5, 10, 16 |
| `ww-smart-city-iot` | smart cities and IoT telemetry | device registry, time series, events and retention | 6, 7, 9, 11, 13 |
| `ww-energy-grid` | grids and utilities | interval readings, assets, outages and load | 7, 9, 11, 13 |
| `ww-renewables` | renewable energy | generation telemetry, asset performance and maintenance | 7, 9, 12, 13 |
| `ww-climate-carbon` | climate, carbon and ESG | emissions factors, boundaries, evidence and versioned calculations | 7, 12, 13, 14, 15 |
| `ww-ngo-humanitarian` | NGOs and humanitarian logistics | assistance pipeline, stock, referrals and aggregate results | 1, 2, 3, 10, 16, 17 |
| `ww-sports-leagues` | sports leagues and federations | teams, eligibility, fixtures, results and discipline workflow | 3, 5, 10, 16 |
| `ww-gaming` | gaming and matchmaking | identity-safe profiles, matchmaking, leaderboards and anti-abuse | 3, 5, 9, 16 |
| `ww-siem-audit` | cybersecurity SIEM and audit events | event ingestion, retention, detection and incident workflow | 9, 16 |
| `ww-ledger-blockchain` | blockchain-adjacent ledgers | append-only events, reconciliation and external proof references | 9, 12, 16 |
| `ww-ml-feature-store` | AI/ML feature stores and MLOps | feature definitions, lineage, point-in-time correctness, model versions | 9, 12, 13 |
| `ww-data-warehouse` | data warehouse / lakehouse | star schema, snowflake, Data Vault, lineage and freshness | all as domain-dependent |
| `ww-data-exchange` | inter-organisation exchange | schema contracts, versioning, reconciliation and authority controls | 9, 16, 17 |
| `ww-document-retention` | records and retention | classification, legal holds, disposition and access logs | 16 |
| `ww-customer-support` | support and service levels | tickets, queues, response/resolution intervals and quality | 8, 9, 10 |
| `ww-subscriptions-billing` | subscriptions and recurring billing | entitlements, invoices, renewals, proration and reversals | 8, 9 |
| `ww-identity-access` | identity and access management | actors, roles, grants, lifecycle, access reviews and audit | 5, 10, 16 |
| `ww-consent-privacy` | consent, privacy and retention | purpose, lawful basis, preference history, export and deletion workflow | 3, 5, 10, 16 |
| `ww-inventory-traceability` | batch/serial traceability | custody events, recalls, suppliers and lot genealogy | 2, 3, 8, 9, 12 |
| `ww-research-surveys` | surveys and research | study metadata, sampling, data quality and reproducibility | 3, 4, 5, 10, 13 |
| `ww-public-transit` | public transit and mobility | stop, route, schedule, disruption and aggregate reliability | 9, 10, 11, 13 |
| `ww-real-estate` | real estate and property management | units, leases, maintenance, valuations and payment references | 8, 9, 11 |
| `ww-agriculture-food` | agriculture and food systems | farm, harvest, trade, storage, food safety and waste | 1, 2, 3, 12, 13, 15 |
| `ww-water-sanitation` | water and sanitation | water quality, assets, service coverage and outage events | 3, 6, 11, 12 |
| `ww-biodiversity` | biodiversity and conservation | survey observation, taxonomy, habitat and provenance | 13, 14, 15 |
| `ww-circular-economy` | waste and circular economy | collection, materials recovery, reuse and lifecycle metrics | 11, 12, 13, 14, 15 |
| `ww-supply-chain-risk` | supply-chain risk | supplier tiers, incidents, remediation and provenance | 8, 9, 12, 16, 17 |

## 7. UN Sustainable Development Goals (SDGs 1–17)

SDG identifiers are stable; the mapping from a domain to an SDG is contextual and should be documented per project. Do not claim a database project achieves a goal merely because it reports a related indicator.

| Slug | Goal | Common data-backbone examples |
|---|---|---|
| `ww-sdg-01` | No Poverty | social protection, income/service access indicators |
| `ww-sdg-02` | Zero Hunger | agricultural productivity, nutrition and food logistics |
| `ww-sdg-03` | Good Health and Well-being | health services, medicines and public-health aggregates |
| `ww-sdg-04` | Quality Education | school access, learning services and education outcomes |
| `ww-sdg-05` | Gender Equality | disaggregated indicators with safe disclosure controls |
| `ww-sdg-06` | Clean Water and Sanitation | service access, quality, reliability and sanitation |
| `ww-sdg-07` | Affordable and Clean Energy | generation, access, outages and efficiency |
| `ww-sdg-08` | Decent Work and Economic Growth | work, business activity, safety and productivity |
| `ww-sdg-09` | Industry, Innovation and Infrastructure | infrastructure assets, manufacturing and innovation funding |
| `ww-sdg-10` | Reduced Inequalities | inclusion, accessibility and distributional analysis |
| `ww-sdg-11` | Sustainable Cities and Communities | transport, housing, waste, resilience and local service delivery |
| `ww-sdg-12` | Responsible Consumption and Production | inventory, waste, procurement and product traceability |
| `ww-sdg-13` | Climate Action | risk, emissions, adaptation and climate telemetry |
| `ww-sdg-14` | Life Below Water | fishery, lake/ocean quality and aquatic biodiversity |
| `ww-sdg-15` | Life on Land | land, forest, soil and terrestrial biodiversity |
| `ww-sdg-16` | Peace, Justice and Strong Institutions | accountable processes, access to justice and auditability |
| `ww-sdg-17` | Partnerships for the Goals | data exchange, metadata, funding and common indicators |

Official SDG reference: [United Nations Sustainable Development Goals](https://sdgs.un.org/goals).

## 8. Minimum metadata to add for each indexed unit

Every implementation should register:

- slug, display name, category, parent unit, jurisdiction and lifecycle state;
- data owner, operational owner, security owner and review date;
- legal authority / purpose, data-sharing authority and privacy classification;
- target database engine/version and optional extension list;
- migration version, last successful test run and last reviewed commit;
- upstream/downstream dependencies, source-of-truth rules and retention schedule;
- status: `planned`, `discovery`, `in_progress`, `review`, `implemented`, `retired`.

No index row implies endorsement, access permission, completeness of source data, or production readiness.


## 9. Government directory snapshot — 116 listed entries

The Government Media Centre directory was reviewed on 14 October 2026 and stated that it lists **116 ministries and agencies**. The 116 slugs below map its displayed entries in page order, including offices, regional portfolios, commissions, statutory bodies, public corporations and other listed organisations. This is a catalogue snapshot, not a legal opinion or proof that every entry has independent ministry status. Confirm the legal name, current mandate, parent and operational status with the responsible authority before implementation. The directory itself may change.

Source: [Government Media Centre — Ministries of the Republic](https://mediacentre.go.ug/ministries). Cross-check central-government portfolio relationships against [State House — The Cabinet](https://statehouse.go.ug/the-cabinet/) and [Parliament of Uganda — Cabinet members and Ministers of State](https://web.parliament.go.ug/page/cabinet-members-and-ministers-state).

| Directory order | Stable slug | Directory display name |
|---:|---|---|
| 1 | `ug-kiswahili-language-office` | Dawati La Kiswahili Coordinator's Office |
| 2 | `ug-kcca` | Kampala Capital City Authority |
| 3 | `ug-p-karamoja-affairs` | Ministry for Karamoja Affairs |
| 4 | `ug-p-northern-uganda` | Ministry for Northern Uganda |
| 5 | `ug-m-aaiif` | Ministry of Agriculture, Animal Industry & Fisheries |
| 6 | `ug-m-defence-veterans` | Ministry of Defence and Veteran Affairs |
| 7 | `ug-p-disaster-preparedness` | Ministry of Disaster Preparedness |
| 8 | `ug-m-eac-affairs` | Ministry of East African Community Affairs |
| 9 | `ug-m-education-sports` | Ministry of Education and Sports |
| 10 | `ug-m-energy-minerals` | Ministry of Energy and Mineral Development |
| 11 | `ug-m-finance-planning` | Ministry of Finance, Planning & Economic Development |
| 12 | `ug-m-foreign-affairs` | Ministry of Foreign Affairs |
| 13 | `ug-m-gender-labour-social` | Ministry of Gender, Labour & Social Development |
| 14 | `ug-m-health` | Ministry of Health |
| 15 | `ug-m-ict-national-guidance` | Ministry of ICT and National Guidance |
| 16 | `ug-m-internal-affairs` | Ministry of Internal Affairs |
| 17 | `ug-m-justice-constitutional` | Ministry of Justice & Constitutional Affairs |
| 18 | `ug-m-lands-housing-urban` | Ministry of Lands, Housing & Urban Development |
| 19 | `ug-m-local-government` | Ministry of Local Government |
| 20 | `ug-m-public-service` | Ministry of Public Service |
| 21 | `ug-p-refugee-affairs` | Ministry of Refugees & OPM Refugees Department |
| 22 | `ug-m-science-tech-innovation` | Ministry of Science, Technology & Innovation |
| 23 | `ug-m-tourism-wildlife-antiquities` | Ministry of Tourism, Wildlife and Antiquities |
| 24 | `ug-m-trade-industry-coops` | Ministry of Trade, Industry & Cooperatives |
| 25 | `ug-m-water-environment` | Ministry of Water and Environment |
| 26 | `ug-m-works-transport` | Ministry of Works and Transport |
| 27 | `ug-op` | Office of the President |
| 28 | `ug-opm` | Office of the Prime Minister |
| 29 | `ug-ovp` | Office of the Vice President |
| 30 | `ug-state-house` | State House |
| 31 | `ug-m-kampala-metropolitan` | Ministry of Kampala Capital City and Metropolitan Affairs |
| 32 | `ug-parliament` | Parliament of Uganda |
| 33 | `ug-judiciary` | The Judiciary |
| 34 | `ug-umc` | Uganda Media Centre |
| 35 | `ug-ucc` | Uganda Communications Commission |
| 36 | `ug-nita-u` | National Information Technology Authority – Uganda |
| 37 | `ug-ubc` | Uganda Broadcasting Corporation |
| 38 | `ug-vision-group` | Vision Group / New Vision |
| 39 | `ug-uppc` | Uganda Printing and Publishing Corporation |
| 40 | `ug-uict` | Uganda Institute of Information and Communications Technology |
| 41 | `ug-posta` | Posta Uganda |
| 42 | `ug-media-council` | Media Council of Uganda |
| 43 | `ug-utl-legacy` | Uganda Telecommunications Limited |
| 44 | `ug-ura` | Uganda Revenue Authority |
| 45 | `ug-bou` | Bank of Uganda |
| 46 | `ug-npa` | National Planning Authority |
| 47 | `ug-ubos` | Uganda Bureau of Statistics |
| 48 | `ug-ppda` | Public Procurement and Disposal of Public Assets Authority |
| 49 | `ug-uia` | Uganda Investment Authority |
| 50 | `ug-udb` | Uganda Development Bank |
| 51 | `ug-udc` | Uganda Development Corporation |
| 52 | `ug-fia` | Financial Intelligence Authority |
| 53 | `ug-cma` | Capital Markets Authority |
| 54 | `ug-ira` | Insurance Regulatory Authority of Uganda |
| 55 | `ug-urbra` | Uganda Retirement Benefits Regulatory Authority |
| 56 | `ug-nssf` | National Social Security Fund |
| 57 | `ug-msc` | Microfinance Support Centre |
| 58 | `ug-tat` | Tax Appeals Tribunal |
| 59 | `ug-oag` | Office of the Auditor General |
| 60 | `ug-uepb` | Uganda Export Promotion Board |
| 61 | `ug-nwsc` | National Water and Sewerage Corporation |
| 62 | `ug-unra` | Uganda National Roads Authority |
| 63 | `ug-urf` | Uganda Road Fund |
| 64 | `ug-ucaa` | Uganda Civil Aviation Authority |
| 65 | `ug-urc` | Uganda Railways Corporation |
| 66 | `ug-uegcl` | Uganda Electricity Generation Company Limited |
| 67 | `ug-uetcl` | Uganda Electricity Transmission Company Limited |
| 68 | `ug-uedcl` | Uganda Electricity Distribution Company Limited |
| 69 | `ug-era` | Electricity Regulatory Authority |
| 70 | `ug-pau` | Petroleum Authority of Uganda |
| 71 | `ug-unoc` | Uganda National Oil Company |
| 72 | `ug-nema` | National Environment Management Authority |
| 73 | `ug-nfa` | National Forestry Authority |
| 74 | `ug-unma` | Uganda National Meteorological Authority |
| 75 | `ug-updf` | Uganda Peoples' Defence Forces |
| 76 | `ug-upf` | Uganda Police Force |
| 77 | `ug-ups` | Uganda Prisons Service |
| 78 | `ug-iso` | Internal Security Organisation |
| 79 | `ug-eso` | External Security Organisation |
| 80 | `ug-dcic` | Directorate of Citizenship and Immigration Control |
| 81 | `ug-nira` | National Identification and Registration Authority |
| 82 | `ug-ursb` | Uganda Registration Services Bureau |
| 83 | `ug-ig` | Inspectorate of Government |
| 84 | `ug-dpp` | Directorate of Public Prosecutions |
| 85 | `ug-uhrc` | Uganda Human Rights Commission |
| 86 | `ug-jsc` | Judicial Service Commission |
| 87 | `ug-psc` | Public Service Commission |
| 88 | `ug-hsc` | Health Service Commission |
| 89 | `ug-esc` | Education Service Commission |
| 90 | `ug-eoc` | Equal Opportunities Commission |
| 91 | `ug-dei` | Directorate of Ethics and Integrity |
| 92 | `ug-ldc` | Law Development Centre |
| 93 | `ug-ulrc` | Uganda Law Reform Commission |
| 94 | `ug-ec` | Electoral Commission |
| 95 | `ug-ulc` | Uganda Land Commission |
| 96 | `ug-lgfc` | Local Government Finance Commission |
| 97 | `ug-ngo-bureau` | National Bureau for Non-Governmental Organisations |
| 98 | `ug-nms` | National Medical Stores |
| 99 | `ug-ubts` | Uganda Blood Transfusion Service |
| 100 | `ug-uci` | Uganda Cancer Institute |
| 101 | `ug-uhi` | Uganda Heart Institute |
| 102 | `ug-nda` | National Drug Authority |
| 103 | `ug-uac` | Uganda AIDS Commission |
| 104 | `ug-uneb` | Uganda National Examinations Board |
| 105 | `ug-ncdc` | National Curriculum Development Centre |
| 106 | `ug-nche` | National Council for Higher Education |
| 107 | `ug-ncs` | National Council of Sports |
| 108 | `ug-umi` | Uganda Management Institute |
| 109 | `ug-naro` | National Agricultural Research Organisation |
| 110 | `ug-naads` | National Agricultural Advisory Services |
| 111 | `ug-ucda` | Uganda Coffee Development Authority |
| 112 | `ug-dda` | Dairy Development Authority |
| 113 | `ug-cdo` | Cotton Development Organisation |
| 114 | `ug-uwa` | Uganda Wildlife Authority |
| 115 | `ug-utb` | Uganda Tourism Board |
| 116 | `ug-unbs` | Uganda National Bureau of Standards |

The official-directory snapshot intentionally coexists with the sector catalogue above: one index row describes an organisation/portfolio, another describes a reusable problem domain. They are different dimensions and must not be conflated.
