# audit-scraper
Checks JS projects for vulnerabilities and their time to upgrade of vulnerable dependencies.

---

audit-scraper is a simple script to fetch all versions of `package.json` for the top 100 JavaScript projects on GitHub and run `npm audit` on them. The logs are then used to determine the mean time to update and other measurements related to the management of vulnerabilities.

---

### Results

The results from scraping can be found for download here: https://bit.ly/2PEEWNo

In the file you will find the following format:

```
github-username/
  project-name/
    commit-timestamp/
      package.json
      package-lock.json
      audit.log
  project-name/
  ...
github-username-2/
...
```

There is a total of 105 projects and around 32000 commits in the results. Uncompressed size is 8.1GB (1.3GB when compressed).

To format these results into CSV you can use `$ ./format.sh -s` (requires you to have `jq` and `hjson` installed). Running the formatter will reduce each project into two CSV files. See the CSV headers for information in the generated files. 

### Slides

You can find the slides for our presentation here: https://bit.ly/2QBkfra
