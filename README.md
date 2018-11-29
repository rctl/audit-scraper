# audit-scraper
Checks JS projects for vulnerabilities and their time to upgrade of vulnerable dependencies.

---

audit-scraper is a simple script to fetch all versions of `package.json` for the top 100 JavaScript projects on GitHub and run `npm audit` on them. The logs are then used to determine the mean time to update and other measurements related to the management of vulnerabilities.

---

Sources from scraping are available at https://scraper.tldr.zone/
