#####

# Description: This script pulls eviction filing counts from 2018 from a Princeton University 
#   Eviction Lab dataset (https://data-downloads.evictionlab.org/). In a subsequent step, these counts are converted to filing rates.
# Original Author: Will Curran-Groome
# Date of Creation: 04/28/2023
#####

# libraries
library(tidyverse)
library(here)
library(tigris)

get_eviction_vars = function(read_cache = F, write_cache = T) {
  
  # INPUTS:
  #   read_cache: if TRUE, read a locally-saved version of the data.
  #   write_cache: if TRUE, write the data to a local directory.
  #   
  # OUTPUTS:
  #   df: a dataframe comprising 2018 eviction filings per tract (2010-vintage tract),
  #     along with a corresponding geoid field uniquely identifying each row.
  
  ## default location for reading/writing data locally
  cache_path = here("data", "intermediate-data", paste0("evictions_", "tract", "_", "2018", ".csv"))
  
  ## read from the local cache_path or, if read_cache == F or there's no locally saved file, pull from the AWS bucket
  if (read_cache == T && file.exists(cache_path)) { 
    eviction_df = cache_path %>% read_csv() %>% mutate(geoid = as.character(geoid)) 
  } else {
     eviction_df = 
       read_csv("https://eviction-lab-data-downloads.s3.amazonaws.com/estimating-eviction-prevalance-across-us/tract_proprietary_2000_2018.csv", 
                col_types = cols(id = col_character())) %>% 
          filter(year == 2018, !is.na(filings)) %>%
          select(geoid = id, filings_2018 = filings)
     }
  
  ## if write_cache is TRUE, write the raw CSV (pre-processing) to the cache path, overwriting any existing file
  if ( write_cache == T ) { eviction_df %>% write_csv(path = cache_path) }
  
  return(eviction_df)
}
