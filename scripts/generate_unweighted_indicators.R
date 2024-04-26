#####
# Description: This script combines data from Census and CHAS datasets and aligns data
#   across different tract-vintages (2010 and 2020), as needed.
# Original Author: Will Curran-Groome
# Date of Creation: 04/28/2023
#####

## libraries
library(tidycensus)
library(sf)
library(readxl)
library(tidycensus)
library(tigris)
library(here)
library(tidyverse)
options(scipen = 999999)
options(tigris_use_cache = T)

## external scripts
source(here("scripts", "list_census_index_vars.R"))
source(here("scripts", "get_census_index_vars.R"))
source(here("scripts", "get_chas_index_vars.R"))
source(here("scripts", "impute_2010_2020_tracts_areal.R"))

generate_unweighted_indicators = function(
    census_year = NA,          # the year for which to pull Census data
    chas_year = NA,                # the year for which to pull CHAS data; when NA, pulls the most recent year available relative to the census_year
    read_cache_all = NA,            # read data from local cache if TRUE
    write_cache_all = NA,           # write data to local cache if TRUE
    read_cache_census = NA,        # dataset specific option; defaults to cache_all
    write_cache_census = NA,       # dataset specific option; defaults to overwrite_all
    read_cache_chas = NA,          # dataset specific option; defaults to cache_all
    write_cache_chas = NA,         # dataset specific option; defaults to overwrite_all
    states = "default",            # 50 states and DC by default; optionally, specify specific states
    geography = "tract",           # the geography at which to create the index
    populated_geography_filter = TRUE,           # filter out geographies without any residents if TRUE
    extremely_lowincome_renter_filter = TRUE,    # filter out geographies without any extremely low-income renters if TRUE
    include_moe = FALSE                           # include margin of error variables from Census if TRUE
) {

  # INPUTS:
  #   (parameters defined above.)
  #   
  # OUTPUTS:
  #   A dataframe comprising the final index indicators.
  
  message(paste0("The cache_all parameter has been set to ", read_cache_all %>% as.character, ". When read_cache_all is set to TRUE, all primary data inputs are read from a locally-stored copy of the
                 data, meaning that any edits to the data generation scripts will not be reflected in the data returned from this function. To ensure you have a current version of the data,
                 set read_cache_all to FALSE (though this takes much longer)."))


  ####----Establishing Default Values----####
  # Validating and setting values for function arguments
  current_year = Sys.Date() %>% lubridate::year()
  current_month = Sys.Date() %>% lubridate::month()
  
  census_max_year = current_year - 1
  
  check_max_census_year <- function(code) {
    tryCatch(code,
             error = function(c){
               census_max_year = current_year -2
               return(census_max_year)
             })}
  
  census_max_year = check_max_census_year(tidycensus::load_variables(year = current_year, dataset = "acs5"))

  chas_max_year = if ( current_month > 9 ) { chas_max_year = current_year - 3 } else { chas_max_year = current_year - 4 }
  
  ## These all technically date back to 2009, but omitting this year as an option
  ## for the time being due to issues with changing tract geometries across the 
  ## decennial census (this script accommodates 2010- and 2020-vintage geometries)
  census_years_available = c(2010:census_max_year)
  chas_years_available = c(2010:chas_max_year)
  census_year = census_year %>% as.numeric
  chas_year = chas_year %>% as.numeric
  
  ## if cache arguments are NA, apply the read/write_cache_all value to each dataset
  if (is.na(read_cache_census)) { read_cache_census = read_cache_all }
  if (is.na(write_cache_census)) { write_cache_census = write_cache_all }
  if (is.na(read_cache_chas)) { read_cache_chas = read_cache_all }
  if (is.na(write_cache_chas)) { write_cache_chas = write_cache_all }
  
  ## either pass in a specified list of states or use the default set 
  ## NOTE: this script has only been tested with the 50 states and DC
  if (states == "default") { states = fips_codes %>% filter(!state %in% c("PR", "UM", "VI", "GU", "AS", "MP")) %>% pull(state) %>% unique() }
  
  ## setting the years for each dataset in the case that the corresponding parameter is NA
  if ( is.na(chas_year) & (census_year > max(chas_years_available)) ) { 
    chas_year = paste0( (census_year - 6) %>% as.character, "thru", (census_year - 2) %>% as.character ) 
  } else if ( is.na(chas_year) ) {
    chas_year = paste0( (census_year - 4) %>% as.character, "thru", census_year %>% as.character )}
  
  print(paste0("The Census data year is: ", census_year %>% as.character))
  print(paste0("The CHAS data year is: ", chas_year %>% as.character))
  
  ####----Reading in Raw Source Data----####
  
  ## American Community Survey (ACS) indicators
  acs = get_census_index_vars(
    census_year = census_year, 
    census_geography = geography, 
    census_variables = list_census_index_vars(),
    census_states = states,
    include_moe = include_moe,
    read_cache = read_cache_census,
    write_cache = write_cache_census) %>% 
    left_join(
      map_dfr(
        states,
        ~ tigris::tracts(
          state = .x,
          cb = T,
          year = census_year)) %>% 
        st_drop_geometry %>% 
        select(GEOID, land_area = ALAND), ## tract areas
      by = "GEOID") %>% 
    mutate(population_density = safe_divide(pba_population_denom, land_area))
  
  ## Comprehensive Housing Affordability Strategy (CHAS) indicators
  chas = get_chas_index_vars(
    chas_year = chas_year,
    read_cache = read_cache_chas,
    write_cache = write_cache_chas)
  
  ####----Aligning Data across Different Geography Vintages----####
  
  ## this may need to be adjusted in future years if/when these datasets update to using 2020 geographies
  if (census_year > 2019 & !(str_detect(chas_year, "202"))) {
    ## areal imputation of data from 2010 to 2020 census tracts (or other geographies, as appropriate)
    chas = chas %>% impute_2010_2020_tracts_areal(df_geoid = "GEOID")
    areal_imputation_flag = T
  } else {
    areal_imputation_flag = F
  }
  
  indicators_df = acs %>% 
    { if (census_year > 2019 & !(str_detect(chas_year, "202"))) rename(., GEOID_TRACT_20 = GEOID) else . } %>% ## adjusting column names depending on areal imputation
    left_join(chas) %>%
    mutate(perc_renter_lessthanequal_30hamfi = safe_divide(renter_lessthanequal_30hamfi, renter_total)) %>% #hamfi = hud area median family income
    {if (census_year > 2019 & !(str_detect(chas_year, "202"))) rename(., geoid = GEOID_TRACT_20) else . } %>% ## adjusting column names depending on areal imputation
    rename(population_total = pba_population_denom)
  
  ## depending on the years used, the geographic id column might have differing names
  ## whatever it's called, we select the name of it here (to rename as geoid in the subsequent step)
  geoid_col = str_extract(string = colnames(indicators_df), pattern = regex("geoid", ignore_case = T)) %>% .[!is.na(.)]

  unweighted_indicators = indicators_df %>%
    select(
      geoid = all_of(geoid_col), 
      state_name, 
      population_total,
      matches("^perc"),
      avg_household_size_renters,
      median_housing_cost,
      renter_lessthanequal_30hamfi) %>%
    {if (populated_geography_filter == T) { filter(., !(is.na(population_total) | population_total == 0)) } else . } %>%
    {if (extremely_lowincome_renter_filter == T) { filter(., renter_lessthanequal_30hamfi > 0) } else . }
  
  return(unweighted_indicators)
}
