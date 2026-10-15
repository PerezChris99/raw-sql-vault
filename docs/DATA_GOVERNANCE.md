# Data Governance, Privacy, and Provenance

## Default: synthetic data
Fixtures should be synthetic and clearly labelled. Do not include personal records, credentials, production extracts, confidential records, or sensitive narratives. Public accessibility does not automatically grant reuse rights.

## Provenance
For every non-synthetic dataset document source, owner, collection date, licence/terms, allowed purpose, attribution, personal-data status, transformation, retention, and redistribution approval. Exclude data while these facts are unknown.

## Classification
A deployment may use labels such as Public, Internal, Confidential, and Restricted. Treat these as design aids, not a legal classification scheme; follow the data owner's and jurisdiction's rules.

## Minimisation and purpose
Store only what the purpose requires. Prefer opaque references, aggregation, and tokenisation when appropriate. Pseudonymised data may still be personal data. Keep linkage keys separate and access-controlled. Do not add real names, national identifiers, exact addresses, clinical narratives, beneficiary lists, or account details merely to make demos realistic.

## Access, retention, deletion
Real deployments must define owner/controller, authorised processors, purpose/lawful basis, role and tenant boundaries, retention and legal holds, deletion/correction/export, audit, access review, incident reporting, and backup expiry. Audit history must not be used as a loophole to retain data contrary to policy.

## High-impact systems
Health, children, education, credit, employment, justice, immigration, humanitarian assistance, public benefits, and essential services need heightened human, privacy, fairness, safety, and domain review. Do not make unreviewed high-impact decisions solely from database scores or incomplete data. Provide accountable human review and correction/appeal paths where applicable.

## Institutional references and public issues
Validate institution names, administrative structures, laws, and mandates against current authoritative sources and data owners. The repository does not imply official approval or access to government data. Never attach raw dumps, credentials, private keys, personal records, or confidential incident evidence to public issues.

## Review checklist
- [ ] Purpose and data owner are documented.
- [ ] Data is synthetic or approved for this exact reuse.
- [ ] Collection and redistribution rights are recorded.
- [ ] Fields are minimised and classified.
- [ ] Access, retention, deletion, and audit rules are explicit.
- [ ] High-impact decisions have accountable human oversight.
- [ ] Exports, logs, backups, and analytics copies are covered.
- [ ] Required legal/privacy/security reviewers have approved the context.
