#####
# Description: This script returns a vector of ACS variables names used in the development of the index.
#   Note that variable names not included in the final index have been commented out for posterity.
# Original Author: Will Curran-Groome
# Date of Creation: 04/28/2023
#####

# Load variable metadata from 5-year ACS
# vars_list <- load_variables(year = census_year, dataset = census_dataset, cache = TRUE)

list_census_index_vars = function() {
  # INPUTS:
  #   None.
  #   
  # OUTPUTS:
  #   A character vector of 5-year ACS variable names.
  
  ####----ACS Variables by Concept----####
  
  ## vars for calculating project-based assistance percentages (pba)
  ## B01001_001 = the denominator for age x sex variables, is used as total population
  ## B25003_001 = the denominator for total occupied housing units
  pba_vars = c("B01001_001", "B25003_001")
  
  ## cost burdened (cb)
  cb_vars = c("B25074_001", "B25074_002", "B25074_011", "B25074_020", "B25074_009", "B25074_018", "B25074_027", "B25074_010", "B25074_019", "B25074_028")
  
  ## share renters (sr)
  sr_vars = c("B25003_003", "B25003_001")
  
  ## race (race)
  race_vars = c("B03002_001", "B03002_004", "B03002_003", "B03002_012", "B03002_005", "B03002_006", "B03002_007", "B03002_008", "B03002_009")
  
  ## household size (hs)
  hs_vars = c("B25010_003", "B25009_010", "B25009_011", "B25009_012", "B25009_013", "B25009_014", "B25009_015", "B25009_016", "B25009_017")
  
  ## median monthly housing cost (hc)
  hc_vars = c("B25105_001")
  
  ## tenure by units in structure
  ## renter-occupied housing units with more than one unit per structure
  unit_size_vars = c("B25032_013", "B25032_016", "B25032_017", "B25032_018", "B25032_019", "B25032_020", "B25032_021", "B25032_022", "B25032_023")
  
  acs_vars = c(
    pba_vars, 
    cb_vars, 
    sr_vars, 
    race_vars, 
    hs_vars, 
    hc_vars, 
    unit_size_vars) 
}