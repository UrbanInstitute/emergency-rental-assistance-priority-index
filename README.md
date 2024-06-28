# Emergency Rental Assistance Priority (ERAP) Index 2.0

This repository contains the data and code necessary to generate the census tract-level Emergency Rental Assistance Priority Index that powers this [interactive Urban feature](https://www.urban.org/data-tools/mapping-neighborhoods-highest-risk-housing-instability-and-homelessness).

The code for the [front-end interactive feature is available here](https://github.com/UrbanInstitute/mapping-neighborhoods-highest-risk-housing-instability-and-homelessness). The final data can be downloaded from the [project's Data Catalog page](https://datacatalog.urban.org/dataset/rental-assistance-priority-index-20). For additional details on the development of the Index, refer to the project's [Technical Report](https://www.urban.org/research/publication/emergency-rental-assistance-priority-index-version-2).

The ERAP Index 2.0 is composed of three subindices: the Housing Subindex, the Household Demographics Subindex, and the Income Subindex. Each of the subindices contains multiple indicators; when combined, they produce an overarching Index score that reflects the tract-level need for emergency rental assistance. The indicators and the corresponding data sources are listed below.

## Indicators

### Housing Subindex

-   **Share of renter-occupied housing units**: share of all occupied units that are occupied by renters
-   **Share of renter-occupied housing units in multi-unit buildings**: share of all renter-occupied units that are in structures with more than one unit
-   **Median monthly housing cost**: median monthly housing cost of all occupied housing units with monthly housing costs

### Household Demographics Subindex

-   **Average renter household size**: number of people in renter households divided by the number of renter households
-   **Share of Black individuals**: share of all individuals that identify as Black and do not identify as Hispanic or Latino
-   **Share of Asian individuals**: share of all individuals that identify as Asian and do not identify as Hispanic or Latino
-   **Share of Latine individuals**: share of all individuals that identify as Hispanic or Latino
-   **Share of Indigenous, Pacific Islander, or multiracial individuals**: share of all individuals that identify as Indigenous, Pacific Islander, or multiracial and do not identify as Hispanic or Latino

### Income Subindex

-   **Share of cost-burdened renter households**: share of renter households with incomes of less than \$35,000 that are paying 50 percent or more of their incomes on rent
-   **Share of extremely low-income renter households**: share of all renter households with incomes at or below 30 percent of the HUD area median family income

## renv

This project uses `library(renv)` to handle package dependencies. `library(renv)` tracks package versions and sources and writes this metadata to a file called a "lock file". To reproduce exactly the same results, it is critical that users have the appropriate package versions installed and loaded. We outline how to correctly use `library(renv)`--and troubleshoot potential issues–below:

-   Clone the GitHub repository

-   Open `erap-index.Rproj`

-   Run `renv::init()`

    -   Run `renv::restore()` to install each of the package versions specified in the lock.file

        -   Depending on your installed version of R, this step may generate errors. While using different package versions could in theory lead to different results, we have found that only different versions of `library(gWQS)` create differences in resulting Index values.

        -   One approach is to run `renv::restore(exclude = c("packages-that-produce-errors"))`, so long as `gWQS` is installed per the package version listed in the lock.file.

        -   Another approach is to use the workflow below, again ensuring to omit `gWQS` from the list of packages to install / update. NOTE: This approach does not take note of any package version differences so use with care!

        ```# Load the jsonlite and renv packages
        library(jsonlite)
        library(renv)

        # Read the renv lock file
        lockfile <- fromJSON("renv.lock")

        # Extract the package names
        package_names <- names(lockfile$Packages)

        # Get the names of already installed packages
        installed_packages <- rownames(installed.packages())

        # Find packages that aren't already installed
        packages_to_install <- setdiff(package_names, installed_packages)

        # Install the packages
        renv::install(packages_to_install)

## Scripts

-   `001_generate_full_index.qmd`: this composes the below scripts to generate the full ERAP Index.

-   `generate_unweighted_indicators.R`: this compiles raw data from various sources into a single dataframe of indicators.

-   `list_census_index_vars.R`: this returns a character vector of American Community Survey (ACS) variable names.

-   `get_census_index_vars.R`: this downloads, formats, and calculates the indicators described above, (with the exception of share of extremely low-income renter households, which is derived from CHAS data described below) using data from the [American Community Survey](https://www.census.gov/programs-surveys/acs/data.html).

-   `get_eviction_vars.R`: this downloads, formats, and returns 2018 eviction filing counts by census tract provided by the [Evictions Lab](https://data-downloads.evictionlab.org/#estimating-eviction-prevalance-across-us/) at Princeton University.

-   `get_chas_index_vars.R`: this downloads, formats, and returns the number of renters and the number of renters whose income is less than or equal to 30% of the HUD Area Median Family Income (HAMFI) for each census tract from HUD's [CHAS](https://www.huduser.gov/portal/datasets/cp.html) (Comprehensive Housing Affordability Strategy) dataset.

-   `impute_2010_2020_tracts_areal.R`: this attributes data at the 2010-Census-tract level to the 2020-Census-tract level via area-based interpolation based on [data](https://www2.census.gov/geo/pdfs/maps-data/data/rel2020/tract/explanation_tab20_tract20_tract10.pdf) provided by the Census Bureau. Note that field names do not have formal definitions from Census. We provide descriptions of the fields used for imputation below:

    -   `GEOID_TRACT_20`: the 2020 tract GEOID.
    -   `GEOID_TRACT_10`: the 2010 tract GEOID.
    -   `AREALAND_TRACT_20`: the area of the 2020 tract geography that is land (as opposed to water).
    -   `AREALAND_TRACT_10`: the area of the 2010 tract geography that is land (as opposed to water).
    -   `AREALAND_PART`: the land area of the 2020 tract geography that falls within the intersecting 2010 tract. alternately, the land area of the 2010 tract geography that falls within the intersecting 2020 tract.
    -   `perc_2010tractlandarea_in_2020tractlandarea`: the land area of the intersection between a given 2010 tract and 2020 tract divided by the 2010 tract land area.

-   `get_wqs_scores.R`: this formats the index to include only our selected indicators, groups the indicators into their associated subindices, and calculates the weights of each subindex to maximize the correlation of the overall index score with evictions. This also calculates the z-score and percentile ranking for each of our indicators and each subindex.

-   `technical_appendix_content.qmd`: this generates figures and other statistics incorporated in the project's technical appendix.

-   `index_update_validation.qmd`: this contains a workflow for checking that any updates to the codebase preserve the ability to reproduce prior years' data.

## Rerunning the Index with Data from Different Years

-   Whether you are updating the index with more current data or producing the index for a previous year, the following steps outline the overaching process:
    -   Create a new branch on the public-facing repository (named, e.g., "[YEAR]-updates”)
    -   In `/scripts/001_generate_full_index.qmd`
        -   Update the dataset years (for ACS and CHAS data) in the second chunk (named parameters)
        -   Run all chunks
    -   Check the ACS and CHAS data for, at a minimum:
        -   Records accurately join to 2020-vintage census tracts or whatever vintage is the most current for your data
        -   There is limited or no (unexpected) missingness in all indicators
        -   For ACS data, ensure that variable names or construction have not changed over time; variable alignment can be checked using: <https://www2.census.gov/data/api-documentation/2022-5yr-api-changes.csv> (or the equivalent for the given year)
    -   Re-run the correlations between all index indicators and the evictions data (2018 vintage, as of writing in 2024); correlations should be fairly similar (if not, take pause)
    -   Quality-check the final outputted datasets
        -   Run `skimr::skim()` and look at minima and maxima for all variables, as well as rates of missingness (which should be zero or very low for all variables)
        -   Check distributions of any z-scored percentiles, should be a flat distribution from 1-100
        -   Check that the number of records in each dataset is as anticipated (1 record per 2020-vintage tract, roughly)
-   Potential errors/issues when updating the Index with different years:
    -   The `generate_unweighted_indicators.R` script may try to call for ACS or CHAS years that are unavailable. Double check that the set parameters for `census_year` and `chas_year` are years for which each respective source has data available
    -   CHAS data and ACS data across different years may use differing prefixes for each census tract's `GEOID`, this may cause errors when joining the two dataset together. Ensure that the different `GEOID` prefixes (i.e. "14000US" vs "14000000US") are accounted for in the `generate_unweighted_indicators.R` and removed appropriately before joining.
    -   With the updated 2016-2020 CHAS data, the areal imputation from 2010 census tract vintages to 2020 tract vintages is no longer needed as now both the ACS and CHAS using 2020 vintages
        -   Ensure that the impute_2010_2020_tracts_areal() script is not being run on either dataset, unless you are intentionally running the scripts with pre-2020 data
-   `gWQS` package considerations include:
    -   The `gWQS` package may change the weighting of each index based on which version of the package is installed — note that lockfile is the source of truth for exact reproducibility

## WQS Weights

The weights for each subindex that are calculated using the WQS algorithm are critical for determining total index scores; minor changes, such as in the order of data inputted into the WQS algorithm, can result in different weights. In `001_generate_full_index.qmd`, these are stored in the variable `outcome_index_weights`. We track them over time below for reproducibility / validation purposes. Note, however, that these weights should be the same given the same `outcome_year` specification, and should not change when the `census_year` or `chas_year` values are changed as part of the update process.

-   **2018 `outcome_year` weights:** 0.5766271 0.2715952 0.1517778

## Questions?

Reach out to [wcurrangroome\@urban.org](mailto:wcurrangroome@urban.org).
