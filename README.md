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

## Created Datasets and Caching

-   When the `write_cache` parameter (used across multiple scripts) is set to TRUE, the function will write a copy of the data to a local folder in the repository at `data/intermediate-data` for convenience for future use.

-   When the `read_cache` parameter (used across multiple scripts) is set to TRUE, the function will first attempt to read a local copy of the data (if it exists) before pulling the data from a remote location in order to save time.

## Questions?

Reach out to [wcurrangroome\@urban.org](mailto:wcurrangroome@urban.org).
