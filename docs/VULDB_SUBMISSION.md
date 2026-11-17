# VulDB Submission Instructions

VulDB is an independent vulnerability database and CVE Numbering Authority (CNA). Submitting to VulDB ensures attribution even if the vendor does not assign CVEs.

## Submission URL

https://vuldb.com/vuln/add

## Process

1. **Visit the submission form**: https://vuldb.com/vuln/add
2. **Fill in the required fields** using the prepared submission documents:
   - For SGW-2026-001: Use `docs/vuldb-submission-SGW-2026-001.md`
   - For SGW-2026-002: Use `docs/vuldb-submission-SGW-2026-002.md`

## Required Information

Both submission documents contain all required information:
- Vendor name
- Product name
- Affected versions
- Vulnerability class
- Detailed description
- Proof of concept
- Affected component
- Impact assessment
- Remediation recommendations
- References

## Timeline

- VulDB typically processes submissions within 2-7 business days
- Initial processing usually starts within 2-12 hours
- If CVE assignment is requested, VulDB will coordinate with other CNAs
- VulDB is a certified CNA and can assign CVEs directly

## Why Submit to VulDB?

1. **Independent attribution**: VulDB credits the submitter regardless of vendor action
2. **CVE assignment**: VulDB is a certified CNA and can assign CVEs if the vendor doesn't
3. **Public disclosure**: Ensures the vulnerability is documented in an independent database
4. **Vendor coordination**: VulDB will coordinate with the vendor if needed

## After Submission

Once VulDB processes the submissions:
1. Update the advisories with VulDB IDs
2. Add VulDB links to the references section
3. Update the disclosure timeline
4. If CVEs are assigned, update the advisory frontmatter

## Notes

- Both vulnerabilities are already public via:
  - Research repository (public)
  - Upstream issue #378 (public)
  - GHSA advisories (published under fork)
- This is coordinated disclosure, not blind publication
- All information is ready for immediate submission
