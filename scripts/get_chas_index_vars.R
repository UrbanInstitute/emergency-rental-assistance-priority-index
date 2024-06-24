#####
# Description: This script downloads, selects, and cleans variables from HUD's 
#   Comprehensive Housing Affordability Strategy (CHAS) data.
# Original Author: Will Curran-Groome
# Date of Creation: 04/28/2023
#####

# geographies: 
# tract: -140-
# place: -160-
# county: -050

# years:
# earliest end-year: 2009
# latest (as of 04/28/2023) end-year: 2019

# libraries
library(tidyverse)
library(here)

get_chas_index_vars = function(
    chas_year = NA) { # the string corresponding to the range of years of CHAS data
  
  # INPUTS:
  #   (parameters defined above.)
  #   
  # OUTPUTS:
  #   A dataframe comprising three variables: GEOID, renter_total, and renter_lessthanequal_30hamfi.
  #   Note that these data are in 2010-vintage tract geographies as of 04/28/2023.
  #   This corresponds to the dataset for ACS data.

  chas_geography = "-140-"
  
  chas_geography_simple = chas_geography %>% str_remove_all("-")
  initial_zip_destination = here("data", "raw-data", "hud_files.zip")
  
  print(paste0("The CHAS year is: ", chas_year %>% as.character()))
  
  download.file(
    url = paste0("https://www.huduser.gov/portal/datasets/cp/", chas_year, chas_geography, "csv.zip"), 
    destfile = initial_zip_destination,
    method = "libcurl")
    
  ## the directory structure varies across years -- this pulls the file path matching "Table8.csv:
  filename = unzip(zipfile = initial_zip_destination, list = T) %>% pull(Name) %>% str_match(".*Table8.csv") %>% .[!is.na(.)]
  
  download_folder = here("data", "raw-data")
  
  ## unpack the zipped folder
  unzip(zipfile = initial_zip_destination, exdir = download_folder)
  
  chas_income_vars <- read_csv(here(download_folder, filename))
  
  # HAMFI: HUD Area Median Family Income
  # T8_est68 = all renter-occupied
  # T8_est69 = renter-occupied, less than or equal to 30% HAMFI
  
  #replacing prefix in GEOIDs
  geoid_prefix <- c("1400000US|14000US")
  
  chas_income_stats <- chas_income_vars %>%
    select(old_geoid = geoid, renter_total = T8_est68, renter_lessthanequal_30hamfi = T8_est69) %>%
    mutate(GEOID = str_replace_all(old_geoid, geoid_prefix, "")) %>%
    select(-old_geoid)
 
  return(chas_income_stats)
   
}

