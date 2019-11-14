

#'--- 
#' title: "LGH Evergreen Unit ED visits"
#' author: "Nayef Ahmad"
#' date: "2019-11-13"
#' output: 
#'   html_document: 
#'     keep_md: yes
#'     code_folding: show
#'     toc: true
#'     toc_float:
#'       collapsed: false
#'     toc_folding: false
#' ---
#' 

#+ lib, include = FALSE
library(tidyverse)
library(denodoExtractor)
library(lubridate)
library(DT)
library(kableExtra)

setup_sql_server()
setup_denodo()

#+ rest 


#' first pull data on Evergreen pts from CommunityMart PARISIntervention
#' 
#' 
df1.evergreen <- 
  vw_community_paris_intervention %>% 
  filter(CommunityRegion == "Coastal Urban", 
         InterventionDateFrom > "2014-01-01") %>% 
  select(PatientID, 
         InterventionDateFrom, 
         InterventionDateTo,
         InterventionTeam,
         InterventionDept,
         CommunityLHA,
         CommunityRegion,
         CommunityProgram, 
         InterventionCode,
         InterventionDesc, 
         InterventionTypeDesc,
         ExternalProvider) %>% 
  collect() %>% 
  
  filter(grepl("^Evergreen.*", ExternalProvider)) %>% 
  
  mutate(InterventionDateTo = ifelse(is.na(InterventionDateTo),
                                     as.character(today()), 
                                     InterventionDateTo)) %>% 
  
  mutate(InterventionDateFrom = ymd(InterventionDateFrom),
         InterventionDateTo = ymd(InterventionDateTo)) %>% 
  
  arrange(InterventionDateFrom,
          PatientID)


#' Next pull ED data and acute data
#' 
#' 

df2.ed <- 
  vw_eddata %>% 
  filter(facility_short_name == "LGH", 
         start_date_id >= "20140101") %>% 
  select(patient_id, 
         start_date_id, 
         left_ed_date_id) %>% 
  collect() %>% 
  mutate(start_date = ymd(start_date_id))

df3.acute <- 
  vw_admission_discharge %>% 
  filter(facility_short_name == "LGH", 
         admit_date_id >= "20140101") %>% 
  select(patient_id, 
         admit_date_id, 
         disch_date_id, 
         # nursing_unit_desc_at_ad, 
         nursing_unit_desc_at_admit) %>% 
  collect() %>% 
  mutate(admit_date = ymd(admit_date_id))




#' Inner join Evergreen pts and ED data
#' 

df4.ed_usage <- 
  df1.evergreen %>% 
  inner_join(df2.ed, 
             by = c("PatientID" = "patient_id")) %>% 
  filter(start_date >= InterventionDateFrom, 
         start_date <= InterventionDateTo) %>% 
  mutate(ed_visit_id = 1:n())



#' Inner join Evergreen pts and acute data
#' 

df5.acute_usage <- 
  df1.evergreen %>% 
  inner_join(df3.acute, 
             by = c("PatientID" = "patient_id")) %>% 
  filter(admit_date >= InterventionDateFrom, 
         admit_date <= InterventionDateTo,
         !grepl("^EGH.*", nursing_unit_desc_at_admit)) %>% 
  mutate(acute_visit_id = 1:n())


#' # Analysis
#' 

# Analysis ----------
n1_ed_pts <- 
  df4.ed_usage %>% 
  count(PatientID) %>% 
  nrow

n2_ed_visits <- df4.ed_usage %>% nrow()

n3_acute_pts <- 
  df5.acute_usage %>% 
  count(PatientID) %>% 
  nrow

n4_acute_stays <- df5.acute_usage %>% nrow()

# pull it all together: 
data.frame(num_ed_pts = n1_ed_pts, 
           num_ed_encntrs = n2_ed_visits, 
           num_acute_pts = n3_acute_pts, 
           num_acute_encntrs = n4_acute_stays) %>% 
  gather() %>% 
  kable() %>% 
  kable_styling(bootstrap_options = c("striped",
                "condensed", 
                "responsive")) 

              


df5.acute_usage %>% 
  count(nursing_unit_desc_at_admit) %>% 
  arrange(desc(n)) %>% 
  datatable(extensions = 'Buttons',
            options = list(dom = 'Bfrtip', 
                           buttons = c('excel', "csv")))
                           

df6.ed_by_day <- 
  df4.ed_usage %>% 
  count(start_date) %>% 
  fill_dates(start_date, 
             "2014-01-01", 
             "2019-11-13") %>% 
  replace_na(list(n = 0)) 

df6.ed_by_day %>% 
  datatable(extensions = 'Buttons',
            options = list(dom = 'Bfrtip', 
                           buttons = c('excel', "csv")))
                           
# plot 
df6.ed_by_day%>% 
  ggplot(aes(x = dates_fill, 
             y = n)) + 
  # geom_jitter(alpha = 0.3) + 
  geom_smooth() + 
  scale_y_continuous(limits = c(0, 1)) + 
  labs(title = "LGH Evergreen - Average ED encounters per day", 
       y = "num encounters", 
       x = "ED start date") + 
  theme_light() +
  theme(panel.grid.minor = element_line(colour = "grey95"), 
        panel.grid.major = element_line(colour = "grey95"))
  
# plot 
df5.acute_usage %>% 
  count(admit_date) %>% 
  fill_dates(admit_date, 
             "2014-01-01", 
             "2019-11-13") %>% # View("acute")
  replace_na(list(n = 0)) %>% 
  
  ggplot(aes(x = dates_fill, 
             y = n)) + 
  # geom_jitter(alpha = 0.3, 
  #             height = .05) + 
  geom_smooth() + 
  scale_y_continuous(limits = c(0, 1)) + 
  labs(title = "LGH Evergreen - Average acute encounters per day", 
       y = "num encounters", 
       x = "Acute admission date") + 
  theme_light() +
  theme(panel.grid.minor = element_line(colour = "grey95"), 
        panel.grid.major = element_line(colour = "grey95"))

#' Outputs 
#' 

# write_csv(df4.ed_usage,
#           here::here("results",
#                      "dst",
#                      "2019-11-13_lgh_evergreen-pts-in-ED.csv"))
# 
# write_csv(df5.acute_usage,
#           here::here("results",
#                      "dst",
#                      "2019-11-13_lgh_evergreen-pts-in-acute.csv"))
                          