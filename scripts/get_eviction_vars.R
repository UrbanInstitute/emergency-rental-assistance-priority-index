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

get_eviction_vars = function() {
  
  # OUTPUTS:
  #   df: a dataframe comprising 2018 eviction filings per tract (2010-vintage tract),
  #     along with a corresponding geoid field uniquely identifying each row.

  eviction_df = 
   read_csv("https://eviction-lab-data-downloads.s3.amazonaws.com/estimating-eviction-prevalance-across-us/tract_proprietary_2000_2018.csv", 
            col_types = cols(id = col_character())) %>% 
      filter(year == 2018, !is.na(filings)) %>%
      select(geoid = id, filings_2018 = filings)

  return(eviction_df)
}
