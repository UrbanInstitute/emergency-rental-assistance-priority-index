#####
# Description: This script returns raw Census data for index indicators and
#   calculates derived indicators (e.g., percentages) from the raw data.
# Original Author: Will Curran-Groome
# Date of Creation: 04/28/2023
#####

##  return zero rather than NA when the value for the denominator is zero
safe_divide = function(numerator, denominator) { if_else(denominator == 0, 0, numerator / denominator) }

get_census_index_vars = function(
    census_year = 2021, # the year for which to pull data
    census_geography = "tract", # the geography at which to pull data 
    census_variables, # a character vector of census variable names, typically those returned from the script list_census_index_vars.R
    census_dataset = "acs5", # the desired Census dataset
    census_states, # a list of states for which to pull data
    include_moe = F, # include margins of error if TRUE
    read_cache = T, # read a locally-cached version of the data if TRUE, else query the API
    write_cache = T) { # write the data to a local path if TRUE
  
  # INPUTS:
  #   (parameters defined above.)
  #   
  # OUTPUTS:
  #   A dataframe comprising tract-level data. Optionally also writes
  #   as a side-effect a copy of the dataframe to a local directory to eliminate the
  #   need for future calls to the API. 
  
  # path for reading/writing a local version of the data
  cache_path = here("data", "intermediate-data", paste0("acs_", census_geography, "_", census_year, (if_else(include_moe == T, "_including_moes", "")), ".csv"))
  
  ## checks if census data file already exists on local machine and pulls from existing file if TRUE
  ## and if the read_cache argument is set to TRUE
  if (read_cache == T && file.exists(cache_path)) {
    acs2 = cache_path %>% read_csv()
    warning( "ACS data have been loaded from a locally-saved dataset and do not reflect any recent changes that may have been implemented." )
  }
  
  ## if census data file does not exist locally, or if read_cache = F, creates new file with the measures calculated below
  else {
    
    ### ----Pull ACS Indicators---------
    acs_data = map_dfr(
      census_states,
      ~ get_acs(
        state = .,
        variables = census_variables,
        year = census_year,
        geography = census_geography,
        survey = census_dataset,
        output = "wide"))
    
    ### ----Calculate Derived ACS Measures---------
    acs2 =  acs_data %>%
      {if (include_moe == T) select(., GEOID, matches("M$"), matches("E$")) else select(., GEOID, matches("E$"))} %>% ## dropping margin-of-error variables
      rename(
        pba_population_denom = B01001_001E, #project based assistance population denom
        pba_units_denom = B25003_001E, ## project based assistance units denom, also share of renters denom
        race_denom = B03002_001E, # total population, individuals (not households)
        race_black_nonhispanic = B03002_004E, #  non-hispanic black
        race_white_nonhispanic = B03002_003E, # non-hispanic white
        race_hispanic_all = B03002_012E, # hispanic, any race
        race_americanindian_nonhispanic = B03002_005E, # non-hispanic american indian
        race_asian_nonhispanic = B03002_006E, # non-hispanic asian
        race_pacificislander_nonhispanic = B03002_007E, # non-hispanic, pacific islander
        race_other_nonhispanic = B03002_008E, # non-hispanic, other race category
        race_morethanone_nonhispanic = B03002_009E, # non-hispanic, more than one race
        
        ## population = occupied housing units
        hs_denom = B25009_010E, # household size - renter-occupied - denominator
        renter_count = B25003_003E, ## total renter occupied units
        
        ## household size (hs) concept = TENURE BY HOUSEHOLD SIZE
        ## average household size among renter-occupied housing units 
        ## population = renter occupied housing units
        avg_household_size_renters = B25010_003E, # Average household size - Renter occupied
        
        ## housing cost (hc) concept = MEDIAN MONTHLY HOUSING COSTS (DOLLARS)
        ## population = occupied housing units with monthly housing costs
        median_housing_cost = B25105_001E, ## median monthly housing cost

        ## population = all renter occupied units
        renter_units_in_structure_denom = B25032_013E) %>% #renter units in structure denominator
      mutate(
        ## extracting geography identifiers
        state_name = str_split(NAME, ",") %>% map_chr(function(x) x[3]) %>% str_trim,
        county_name = str_split(NAME, ",") %>% map_chr(function(x) x[2]) %>% str_trim,
        state_fips = str_sub(GEOID, 1, 2),
        county_fips = str_sub(GEOID, 1, 5),
        
        ## cost burdened (cb) concept: HOUSEHOLD INCOME BY GROSS RENT AS A PERCENTAGE OF HOUSEHOLD INCOME IN THE PAST 12 MONTHS
        ## percentage of renter households earning less than 35K and spending 50%+ of income on rent as a share of all renter households
        ## population = renter occupied housing units
        perc_cb_under_35k = safe_divide((B25074_009E + B25074_018E + B25074_027E), B25074_001E),
        
        ## share of renters (sr) concept = HOUSING TENURE
        ## percentage of renter occupied units as a share of all occupied housing units
        ## population = all occupied housing units
        perc_sr = safe_divide(renter_count, pba_units_denom),
        num_renters = renter_count, ## retaining this for the online feature
        
        ## race (race) concept = HISPANIC OR LATINO ORIGIN BY RACE
        ## population = total population (individuals, not households)
        perc_race_black_nonhispanic = safe_divide(race_black_nonhispanic, race_denom),
        perc_race_americanindian_nonhispanic = safe_divide(race_americanindian_nonhispanic, race_denom),
        perc_race_pacificislander_nonhispanic = safe_divide(race_pacificislander_nonhispanic, race_denom),
        perc_race_asian_nonhispanic = safe_divide(race_asian_nonhispanic, race_denom),
        perc_race_morethanone_nonhispanic = safe_divide(race_morethanone_nonhispanic, race_denom),
        perc_race_hispanic_all = safe_divide(race_hispanic_all, race_denom),
        perc_race_poc_nonblack_nonhispanic = safe_divide(
          (race_americanindian_nonhispanic + race_asian_nonhispanic + race_pacificislander_nonhispanic + race_other_nonhispanic + race_morethanone_nonhispanic), 
          race_denom),
        perc_race_poc = (perc_race_black_nonhispanic + perc_race_hispanic_all + perc_race_poc_nonblack_nonhispanic),
        perc_race_white_nonhispanic = safe_divide(race_white_nonhispanic, race_denom),
        
        ## tenure by units in structure
        ## percentage of renter units in structures with more than one unit as a share of all renter occupied units
        ## population = renter occupied housing units
        perc_renter_morethanone_units_in_structure = safe_divide(
          B25032_016E + B25032_017E + B25032_018E + B25032_019E + B25032_020E + B25032_021E,
          renter_units_in_structure_denom))
  }
  
  if ( write_cache == T ) { acs2 %>% write_csv(path = cache_path) }
  
  return(acs2)
}
