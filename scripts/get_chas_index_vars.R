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
    chas_year = "2015thru2019",  # the string corresponding to the range of years of CHAS data
    read_cache = T, # read a copy of the data from the local cache if TRUE
    write_cache = T) { #write a copy of the data to the local cache if TRUE
  
  # INPUTS:
  #   (parameters defined above.)
  #   
  # OUTPUTS:
  #   A dataframe comprising three variables: GEOID, renter_total, and renter_lessthanequal_30hamfi.
  #   Note that these data are in 2010-vintage tract geographies as of 04/28/2023.
  
  ## this corresponds to the datasets for tracts
  chas_geography = "-140-"
  
  chas_geography_simple = chas_geography %>% str_remove_all("-")
  initial_zip_destination = here("data", "raw-data", "hud_files.zip")
  
  ## default path for reading/writing locally saved dataset
  cache_path = here("data", "intermediate-data", paste0("chas_", chas_geography, "_", chas_year, ".csv"))
  
  ## if either the cache parameter is FALSE or there's no file at the cache path
  if ( read_cache == F | !file.exists(cache_path) ) {
    download.file(
      url = paste0("https://www.huduser.gov/portal/datasets/cp/", chas_year, chas_geography, "csv.zip"), 
      destfile = initial_zip_destination,
      method = "libcurl")
    
    ## the directory structure varies across years -- this pulls the file path matching "Table8.csv:
    filename = unzip(zipfile = initial_zip_destination, list = T) %>% pull(Name) %>% str_match(".*Table8.csv") %>% .[!is.na(.)]
    
    download_folder = here("data", "raw-data")
    
    ## unpack the zipped folder
    unzip(zipfile = initial_zip_destination, exdir = download_folder)

    ## write the CHAS table of interest to the cache path
    write_csv(read_csv(file.path(download_folder, filename)), cache_path)
  } 
  
  chas_income_vars <- read_csv(cache_path)
  
  # HAMFI: HUD Area Median Family Income
  # T8_est68 = all renter-occupied
  # T8_est69 = renter-occupied, less than or equal to 30% HAMFI
  
  chas_income_stats <- chas_income_vars %>%
    select(old_geoid = geoid, renter_total = T8_est68, renter_lessthanequal_30hamfi = T8_est69) %>%
    mutate(GEOID = str_replace_all(old_geoid, "14000US", "")) %>%
    select(-old_geoid)
  
  ## if overwrite is TRUE, write the raw CSV (pre-processing) to the cache path, overwriting any existing file
  if (write_cache == T) { write_csv(chas_income_vars, cache_path, append = F) }
 
  return(chas_income_stats)
   
}

