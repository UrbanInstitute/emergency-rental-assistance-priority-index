#####
# Description: This script calculates weighted quantile sums-derived weights for each
#   subindex. It requires an indicator index and outcome index, for the case where outcome data
#   (evictions) are from a different year than the indicator data. However, these can also be 
#   identical dataframes in the case where the indicator and outcome data are from the same year.
# Original Author: Judah Axelrod
# Date of Creation: 04/28/2023
#####

# libraries
library(tidycensus)
library(sf)
library(readxl)
library(testit)
library(tigris)
library(here)
library(car)
library(vip)
library(ranger)
library(sm)
library(tidyverse)
library(tidymodels)
library(fastDummies)
library(gWQS)
options(tigris_use_cache = FALSE)
options(scipen = 999999)
sf_use_s2(F)

# external scripts
source(here("scripts", "get_eviction_vars.R"))
source(here("scripts", "impute_2010_2020_tracts_areal.R"))

compute_weights <- function(
    q, # specifies how mixture variables will be ranked (e.g., q = 4 (default) produces quartiles)
    validation, # percentage of the dataset to hold out for validation
    b = 100, # number of bootstrap samples for parameter estimates
    b1_pos = TRUE, # were weights derived from models where beta values were positive?
    formula = `Evictions per 1000 (2018)` ~ wqs, # WQS regression formula
    data, 
    indexes) {
  
  # Fits WQS model for a given number of quantiles and size of the validation set
  wqs_fit <- gwqs(
    formula = formula,
    mix_name = indexes, # the input variables to the model
    data = data, 
    q = q, 
    validation = validation, 
    b = b, 
    b1_pos = b1_pos, 
    family = "gaussian", 
    seed = 24) # sets a seed for replicable results
  
  return(wqs_fit)
}

get_wqs_scores = function(
    indicator_index, # a dataframe of indicators based on data from the specified indicator year
    outcome_index, # a dataframe of indicators based on data from the specified outcome year
    indicator_year, # the specified indicator data year
    outcome_year) { # the specified outcome data year
  
  # INPUTS:
  #   (parameters defined above.)
  #   
  # OUTPUTS:
  #   A list with four items: 
  #     the weighted indicator index (indicator year-vintage data with weights)
  #     the weighted outcome index (outcome year-vintage data with weights)
  #     the WQS-calculated weights when calculated based on outcome index data (these are used for weighting
  #       the first two list items)
  #     the WQS-calculated weights when calculated based on indicator index data (as a reference)
  
  ####----Additional Geography Attributes----####
  census_regions = read_csv("https://raw.githubusercontent.com/cphalpert/census-regions/master/us%20census%20bureau%20regions%20and%20divisions.csv") %>% 
    clean_names() %>%
    rename(
      state_name = state,
      state_abbreviation = state_code,
      census_region = region,
      census_division = division)
  
  ## Download the rural-urban commuting area codes, sourced from: https://www.ers.usda.gov/webdocs/DataFiles/53241/ruca2010revised.xlsx?v=3632.4
  ruca_path = here("data", "raw-data", "ruca2010revised.xlsx") 
  if (!file.exists(ruca_path)) { download.file("https://www.ers.usda.gov/webdocs/DataFiles/53241/ruca2010revised.xlsx?v=3632.4", ruca_path, mode = "wb") }
  
  ## these are in 2010 geographies.
  ruca_raw = read_excel(ruca_path, sheet = "Data", skip = 1) %>%
    clean_names() %>%
    select(
      geoid_tract = state_county_tract_fips_code_lookup_by_address_at_http_www_ffiec_gov_geocode,
      ruca_code_secondary = secondary_ruca_code_2010_see_errata,
      population_density_sqmi = population_density_per_square_mile_2010,
      area_sqmi = land_area_square_miles_2010)
  
  #2010-based tract-level urban-rural designations
  ruca_2010geography <- ruca_raw %>%
    transmute(
      geoid_tract,
      ruca_urban_rural = case_when(
        ruca_code_secondary == 99 ~ NA_character_,
        ruca_code_secondary >= 4 ~ "rural",
        (area_sqmi >= 400 & population_density_sqmi <= 35 & ruca_code_secondary >= 2 & ruca_code_secondary < 4) ~ "rural",
        TRUE ~ "urban"))
  
  #2020-based tract-level urban-rural designations
  ruca_2020geography = ruca_raw %>%
    impute_2010_2020_tracts_areal(df_geoid = "geoid_tract") %>%
    transmute(
      geoid_tract = GEOID_TRACT_20,
      ruca_urban_rural = case_when(
        ruca_code_secondary == 99 ~ NA_character_,
        ruca_code_secondary >= 4 ~ "rural",
        (area_sqmi >= 400 & population_density_sqmi <= 35 & ruca_code_secondary >= 2 & ruca_code_secondary < 4) ~ "rural",
        TRUE ~ "urban"))
        
  ####----Evictions----####
  ## this always pulls 2018 data, the most recent year available. these are in 2010 geographies. 
  evictions_2010geography = get_eviction_vars()
  evictions_2020geography = evictions_2010geography %>% impute_2010_2020_tracts_areal(df_geoid = "geoid")

  ####-----Data Prepped for Modeling----####
  unweighted_indicator_index <- indicator_index %>% 
    { if (indicator_year > 2019) left_join(., ruca_2020geography, by = c("geoid" = "geoid_tract")) 
      else left_join(., ruca_2010geography, by = "geoid_tract") } %>%
    { if (indicator_year > 2019) left_join(., evictions_2020geography, by = c("geoid" = "GEOID_TRACT_20")) 
      else left_join(., evictions_2010geography, by = "geoid") } %>%
    ungroup() %>%
    mutate(
      perc_evictions = (filings_2018 * 1000) / population_total,
      perc_evictions = if_else(population_total == 0, 0, perc_evictions),
      population = population_total,
      `Evictions per 1000 (2018)` = DescTools::Winsorize(perc_evictions, minval = 0, na.rm = T), ## winsorizing; defaults to 95% quantile as upper threshold values
      `% Cost-burdened renter households` = perc_cb_under_35k,
      `% Black` = perc_race_black_nonhispanic,
      `% White` = perc_race_white_nonhispanic,
      `% Indigenous` = perc_race_americanindian_nonhispanic,
      `% Asian` = perc_race_asian_nonhispanic,
      `% Pacific Islander` = perc_race_pacificislander_nonhispanic,
      `% Multiracial` = perc_race_morethanone_nonhispanic,
      `% Hispanic` = perc_race_hispanic_all,
      `% Extremely low–income renters` = perc_renter_lessthanequal_30hamfi,
      `% Renter-occupied units` = perc_sr,
      # Create Other category for racial groups that have high coefficients of variation
      `% Other` = (`% Indigenous` + `% Pacific Islander` + `% Multiracial`),
      ## Flipping signs for variables with negative interpretations (i.e., those where
      ## we expect the eviction filing rate to decrease as the indicator increases).
      ## This is in preparation for the WQS model, which requires positively-signed inputs.
      `Average renter HH size` = -1 * avg_household_size_renters,
      `Median monthly housing cost` = -1 * median_housing_cost, 
      `% Renter-occupied units in multi-unit structures` = perc_renter_morethanone_units_in_structure,
      `Urban Rural Status` = ruca_urban_rural) %>%
    st_drop_geometry %>%
    mutate(across(c(where(is.numeric), -`Evictions per 1000 (2018)`), ~ scale(.x) %>% as.vector)) %>% # Standardize all indicators (z-score) at the national level
    mutate( ## Separate mutate statement because rowMeans can't access recoded variables within the same mutate statement
      housing_subindex = rowMeans(select(., `Median monthly housing cost`, `% Renter-occupied units`, `% Renter-occupied units in multi-unit structures`), na.rm = T),
      income_subindex = rowMeans(select(., `% Cost-burdened renter households`, `% Extremely low–income renters`), na.rm = T),
      household_chars_subindex = rowMeans(select(., `Average renter HH size`, `% Black`, `% Asian`, `% Hispanic`, `% Other`), na.rm = T)) %>%
    select( 
      geoid,
      matches("index"),
      `Evictions per 1000 (2018)`,
      `Median monthly housing cost`,
      `% Renter-occupied units`,
      `% Renter-occupied units in multi-unit structures`,
      `% Cost-burdened renter households`,
      `% Extremely low–income renters`,
      `Average renter HH size`,
      `% Black`,
      `% Asian`,
      `% Hispanic`,
      `% Other`,
      `Urban Rural Status`,
      state_name)

  unweighted_outcome_index = outcome_index %>% 
    left_join(census_regions %>% select(-state_abbreviation), by = "state_name") %>%
    { if (outcome_year > 2019) left_join(., ruca_2020geography, by = c("geoid" = "geoid_tract")) 
      else left_join(., ruca_2010geography, by = c("geoid" = "geoid_tract")) } %>%
    { if (outcome_year > 2019) left_join(., evictions_2020geography, by = c("geoid" = "GEOID_TRACT_20")) 
      else left_join(., evictions_2010geography, by = "geoid") } %>%
    ungroup() %>%
    mutate(
      perc_evictions = (filings_2018 * 1000) / population_total,
      perc_evictions = if_else(population_total == 0, 0, perc_evictions),
      population = population_total,
      `Evictions per 1000 (2018)` = DescTools::Winsorize(perc_evictions, minval = 0, na.rm = T), ## winsorizing; defaults to 95% quantile as upper threshold values
      `% Cost-burdened renter households` = perc_cb_under_35k,
      `% Black` = perc_race_black_nonhispanic,
      `% White` = perc_race_white_nonhispanic,
      `% Indigenous` = perc_race_americanindian_nonhispanic,
      `% Asian` = perc_race_asian_nonhispanic,
      `% Pacific Islander` = perc_race_pacificislander_nonhispanic,
      `% Multiracial` = perc_race_morethanone_nonhispanic,
      `% Hispanic` = perc_race_hispanic_all,
      `% Extremely low–income renters` = perc_renter_lessthanequal_30hamfi,
      `% Renter-occupied units` = perc_sr,
      # Create Other category for racial groups that have high coefficients of variation
      `% Other` = (`% Indigenous` + `% Pacific Islander` + `% Multiracial`),
      ## Flipping signs for variables with negative interpretations (i.e., those where
      ## we expect the eviction filing rate to decrease as the indicator increases).
      ## This is in preparation for the WQS model, which requires positively-signed inputs.
      `Average renter HH size` = -1 * avg_household_size_renters,
      `Median monthly housing cost` = -1 * median_housing_cost, 
      `% Renter-occupied units in multi-unit structures` = perc_renter_morethanone_units_in_structure,
      `Urban Rural Status` = ruca_urban_rural) %>%
    st_drop_geometry %>% 
    select( 
      geoid,
      `Evictions per 1000 (2018)`,
      `Median monthly housing cost`,
      `% Renter-occupied units`,
      `% Renter-occupied units in multi-unit structures`,
      `% Cost-burdened renter households`,
      `% Extremely low–income renters`,
      `Average renter HH size`,
      `% Black`,
      `% Asian`,
      `% Hispanic`,
      `% Other`,
      `Urban Rural Status`,
      state_name) %>%
    mutate(across(-c(geoid, `Evictions per 1000 (2018)`, `Urban Rural Status`, state_name), ~ scale(.x) %>% as.vector)) %>% # Standardize all indicators (z-score) at the national level
    mutate( ## Separate mutate statement because rowMeans can't access recoded variables within the same mutate statement
      housing_subindex = rowMeans(select(., `Median monthly housing cost`, `% Renter-occupied units`, `% Renter-occupied units in multi-unit structures`), na.rm = T),
      income_subindex = rowMeans(select(., `% Cost-burdened renter households`, `% Extremely low–income renters`), na.rm = T),
      household_chars_subindex = rowMeans(select(., `Average renter HH size`, `% Black`, `% Asian`, `% Hispanic`, `% Other`), na.rm = T))  
  
  subindexes <- unweighted_outcome_index %>% select(matches("subindex")) %>% colnames
  
  ####----WQS Modeling----#####
  
  wqs_fit_indicator_index <- compute_weights(
    formula = `Evictions per 1000 (2018)` ~ wqs + `Urban Rural Status`,
    data = unweighted_indicator_index %>% select(-state_name) %>% na.omit(),
    indexes = subindexes,
    q = 10,
    validation = 0.6)
  
  wqs_fit_outcome_index <- compute_weights(
    formula = `Evictions per 1000 (2018)` ~ wqs + `Urban Rural Status`,
    data = unweighted_outcome_index %>% select(-state_name) %>% na.omit(),
    indexes = subindexes,
    q = 10,
    validation = 0.6)
 
  final_indicator_weights = wqs_fit_indicator_index$final_weights %>% pull(mean_weight)
  final_outcome_weights = wqs_fit_outcome_index$final_weights %>% pull(mean_weight)
  
  #####----Calculating Weighted Index Scores----#####
  
  weighted_indicator_index = unweighted_indicator_index %>%
    ## multiplying each subindex by its corresponding gwqs weight
    mutate(total_index = (housing_subindex * final_outcome_weights[1]) + (income_subindex * final_outcome_weights[2]) + (household_chars_subindex * final_outcome_weights[3])) %>%
    group_by(state_name) %>%
    ## zscoring by state and transforming to percentiles
    mutate(across(matches("index"), ~ .x %>% scale %>% ntile(n = 100), .names = "{.col}_zscore_percentile")) %>% 
    ungroup()
  
  weighted_outcome_index = unweighted_outcome_index %>%
    ## multiplying each subindex by its corresponding gwqs weight
    mutate(total_index = (housing_subindex * final_outcome_weights[1]) + (income_subindex * final_outcome_weights[2]) + (household_chars_subindex * final_outcome_weights[3])) %>%
    group_by(state_name) %>%
    ## zscoring by state and transforming to percentiles
    mutate(across(matches("index"), ~ .x %>% scale  %>% ntile(n = 100), .names = "{.col}_zscore_percentile")) %>% 
    ungroup()
  
  ####----Returning Indicator and Outcomes Indexes and Weights (in a list)----####
  
  results = list(weighted_indicator_index, weighted_outcome_index, final_indicator_weights, final_outcome_weights)
  names(results) = c("weighted_indicator_index", "weighted_outcome_index", "indicator_index_weights", "outcome_index_weights")
  
  return(results)
}