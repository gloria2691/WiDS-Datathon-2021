
#Women in data Science Datathon 2021 
# Objective : Classification Problem, predict diabetes yes/no
# target : diabetes_mellitus

### Load packages
require(tidyverse)
require(data.table)

# Define directories
setwd("C:/Users/Asus/Documents/Gloria Valero/Kaggle/widsdatathon2021")
getwd()
data_dir <- file.path(getwd(), "download_dat")
if(!exists(data_dir))print("Data dir 'download_dat' with datathon data not found")
list.files(data_dir)

### Custom settings

source(file.path("functions.R"))

## Step1 - Collecting data /Load data 

codebook <- fread(file.path(data_dir, "DataDictionaryWiDS2021.csv"))

colnames(codebook) <- gsub(" ", "_", tolower(colnames(codebook)))

#Load train data with read.csv. I am not using fread because it generate 
#an issue with Random Forest 

train_df <- read.csv(file.path(data_dir, "TrainingWiDS2021.csv"))

View(codebook)
View(train_df)
  
### Check variables in data and dictionary
cols_not_exist <- which(!((unique(codebook$variable_name)) %in% (colnames(train_df))))
(vars_not_exist <- unique(codebook$variable_name)[cols_not_exist])
codebook <- codebook %>% filter(variable_name != vars_not_exist)


#Step 2 - Pre-processing

### Check for duplicated rows and IDS
dim(train_df)
nrow(distinct(train_df)) == length(unique(train_df$encounter_id))
any(duplicated(train_df$encounter_id))

### Remove columns with same single value
(cols_to_remove = train_df %>% select(where(~length(unique(.)) <= 1))  %>% colnames())
table(codebook$category)
id_vars = codebook$variable_name[codebook$category =="identifier"]
cols_to_remove = c(cols_to_remove, "X",id_vars,"icu_id")
train_df_clean = train_df %>% select(-c(cols_to_remove)) %>% as.data.frame()

### Group variables by category and type
cols_cat <- f_cols_by_cat(codebook)
cols_intstr <- f_get_cols_strint(train_df_clean)

### Declare factor variables
str(train_df_clean[,cols_intstr$character])
train_df_clean[,cols_intstr$character] <- lapply(train_df_clean[,cols_intstr$character]  , factor)
str(train_df_clean[,cols_intstr$character])

### Remove zero variance
df_summary_stats <- train_df_clean %>%
  select_at(cols_intstr$numeric) %>%
  summarize_all(.funs=c("var","mean","median","min","max"), na.rm=TRUE)  %>%
  mutate(dummy=1) %>%
  pivot_longer(cols=-dummy) %>%
  separate(name, into=c("col","metric"), sep="_(?!.*_)") %>%
  arrange(metric, value)
df_variances <- df_summary_stats %>% filter(metric=="var" ) %>% arrange(value)
summary(df_variances$value)
ggplot(data=df_variances)+geom_point(aes(x=value, y=value, group = col))

### Target variable
train_df_clean$diabetes_mellitus <- factor(train_df_clean$diabetes_mellitus, levels=c(0,1), labels=c('nodiabetes','diabetes'))

### Group variables by category
cols_cat <- f_cols_by_cat(codebook)
cols_cat

### Group variables by type
cols_intstr <- f_get_cols_strint(train_df_clean)

#Remove columns with more than 80 % of missing data

train_df_clean <- train_df_clean[,colSums(is.na(train_df_clean))< 0.8*nrow(train_df_clean)]
View(train_df_clean)

###-------- DESCRIPTIVE ---------------------
#length(cols_intstr$numeric)
ints <- seq(1,length(cols_intstr$numeric),11)
p_hist_by_target(dat=train_df_clean, selected_cols=cols_intstr$numeric[1:ints[2]],target_var = 'diabetes_mellitus')
p_hist_by_target(dat=train_df_clean, selected_cols=cols_intstr$numeric[ints[2]:ints[3]],target_var = 'diabetes_mellitus')
p_hist_by_target(dat=train_df_clean, selected_cols=cols_intstr$numeric[ints[3]:ints[4]],target_var = 'diabetes_mellitus')
p_bar_by_target(dat=train_df_clean,selected_cols=cols_intstr$character,target_var = 'diabetes_mellitus')

### Explore by variable category
#length(cols_cat$apachecomorbidity)
p_hist_by_target(dat=train_df_clean, selected_cols=cols_cat$labsbloodgas,target_var = 'diabetes_mellitus')
#p_bar_by_target(dat=train_df_clean,selected_cols=cols_cat$demographic,target_var = 'diabetes_mellitus')

### Save data
## Note , multiple imputation, seletion  by variance or PCA included in train function when using CARET for model fitting
### Other pre-processing steps center, scale (see caret package and target_predictions.R)
fwrite(train_df_clean, file=file.path(data_dir, "TrainingWiDS2021_cleaned.csv"))
  