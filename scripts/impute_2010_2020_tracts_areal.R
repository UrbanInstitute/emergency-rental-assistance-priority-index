#####
# Description: This script interpolates data from 2010-vintage Census tract geographies
#   to 2020-vintage tract geographies.
# Original Author: Will Curran-Groome
# Date of Creation: 04/28/2023
#####

impute_2010_2020_tracts_areal = function(df, df_geoid) {

  # INPUTS:
  #   df: a dataframe with 2010-vintage Census tract data.
  #   df_geoid: the name (character-type) of a column in df that contains tract GEOIDs.
  #   
  # OUTPUTS:
  #   df modified: a dataframe with 2020-vintage Census tract data, interpolated
  #     via area-based interpolation.
  # 
  # DOCUMENTATION:
  #   A description of the 2020-2010 tract relationship file is available at: 
  #     https://www2.census.gov/geo/pdfs/maps-data/data/rel2020/tract/explanation_tab20_tract20_tract10.pdf.
  #   Per the file: "Each record represents on relationship that is formed when a 2020 TRACT intersects a 2010 TRACT."
  #     
  # VARIABLE DEFINITIONS: 
  #   Note that field names do not have formal definitions from Census. We provide
  #   descriptions of the fields used for imputation below:
  #     GEOID_TRACT_20: the 2020 tract GEOID.
  #     GEOID_TRACT_10: the 2010 tract GEOID. 
  #     AREALAND_TRACT_20: the area of the 2020 tract geography that is land (as opposed to water).
  #     AREALAND_TRACT_10: the area of the 2010 tract geography that is land (as opposed to water).
  #     AREALAND_PART: the land area of the 2020 tract geography that falls within the intersecting 2010 tract. 
  #       alternately, the land area of the 2010 tract geography that falls within the intersecting 2020 tract.
  #     perc_2010tractlandarea_in_2020tractlandarea: the land area of the intersection between a given 2010 tract and
  #       2020 tract divided by the 2010 tract land area.
  #     
  # NOTE: population-weighted attribution might be more accurate than using the
  #   somewhat naive areal interpolation approach we take below, e.g., via
  #   https://walker-data.com/tidycensus/reference/interpolate_pw.html
  

  ## this points to the 2010-2020 Census tract relationship file
  initial_destination = here("data", "raw-data", "relationship-files.txt")
  
  ## if the file isn't available locally, download it
  if (!file.exists(initial_destination)) {
    download.file(
      url = paste0("https://www2.census.gov/geo/docs/maps-data/data/rel2020/tract/tab20_tract20_tract10_natl.txt"), 
      destfile = initial_destination,
      method = "libcurl")}
  
  relationships = read_delim(file = initial_destination, delim = "|", col_types = cols(.default = "c")) %>% 
    mutate(
      across(matches("LAND"), as.numeric),
      perc_2010tractlandarea_in_2020tractlandarea = ( AREALAND_PART / AREALAND_TRACT_10 ) %>% round(digits = 8)) %>%
    select(GEOID_TRACT_20, GEOID_TRACT_10, perc_2010tractlandarea_in_2020tractlandarea)
  
  ## each record reflects a unique relationship between a 2020 tract and a 2010 tract
  ## we have data at the 2010 level that we want to attribute to 2020 geographies
  ## so we undertake a three-part process:
  ## 1) calculate the portion of each 2010 tract's land area that falls within each intersecting 2020 tract: perc_2010tractlandarea_in_2020tractlandarea
  ## 2) left join the 2010-based data to our modified relationship file
  ## 3) multiply all count-based fields by perc_2010tractlandarea_in_2020tractlandarea, group_by 2020 tract GEOID, then summarise and sum to create
  ##    indicator values that are proportionally weighted by tract area

  df_interpolated = relationships %>%
    right_join(df, by = c("GEOID_TRACT_10" = df_geoid)) %>%
    select(-any_of("ruca_code_secondary")) %>%
    mutate(
      across(
        c(where(is.numeric), -matches("perc"), -matches(df_geoid)),
        ~ .x * perc_2010tractlandarea_in_2020tractlandarea)) %>%
    group_by(GEOID_TRACT_20) %>%
    summarise(across(
      c(where(is.numeric), -matches("perc"), -matches(df_geoid)),
      ~ sum(.x, na.rm = T)))
  
  if ("ruca_code_secondary" %in% colnames(df)) {
    ## In the case of ruca codes, we want to select the 2010 ruca code that accounts for the greatest portion of
    ## the population in the 2020 tract geography. we create an indicator for this by multiplying the portion of 
    ## the 2010 tract in the 2020 tract by the 2010 area by the 2010 population density (which just gives the population). 
    ## We then take the ruca_code corresponding to the max summed value of this indicator per 2020 tract.
    
    ## Note that the ruca dataset has only 74002 distinct GEOIDs, whereas the relationships
    ## file has 74134 distinct 2010 GEOIDs (i.e., 132 more than the ruca file). This results in a 2020-imputed
    ## ruca dataset with 85359 rows, as opposed to the 85528 distinct 2020 GEOIDs in the relationships file. 
    
    ruca_codes = relationships %>% 
      right_join(df, by = c("GEOID_TRACT_10" = df_geoid)) %>% 
      mutate(weighted_modal_ruca_code = perc_2010tractlandarea_in_2020tractlandarea * area_sqmi * population_density_sqmi) %>%
      group_by(GEOID_TRACT_20, ruca_code_secondary) %>%
      summarise(modal_ruca_code = sum(weighted_modal_ruca_code, na.rm = T)) %>%
      group_by(GEOID_TRACT_20) %>%
      slice(which.max(modal_ruca_code)) %>%
      select(GEOID_TRACT_20, ruca_code_secondary)
    
    df_interpolated = df_interpolated %>% left_join(ruca_codes)
  } 
  
  return(df_interpolated)
}