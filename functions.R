# Title     : Women in data Science Datathon 2021
# Objective : Classification Problem, predict diabetes yes/no
# Team      : SuperSweet
# Related rscripts: data_processing.R, target_prediction.R, functions.R
# Created on: 2/18/2021
###----------------------------------------

f_cols_by_cat <- function(codebook_name = "DataDictionaryWiDS2021.csv"){
  #' Function that returns a list with column names classified according to their category based on a codebook
  #' @param codebook_name file name of the csv codebook to read in IF codebook does not already exist in working environment

  if(!exists("codebook")){
    codebook <- fread(file.path(data_dir, codebook_name))
    colnames(codebook) <- gsub(" ", "_", tolower(colnames(codebook)))
  }
  ### Group variables by category
  #table(codebook$category)
  category_labels = gsub(" ", "", unique(tolower(codebook$category)))
  cols_cat = list()
  for (i in c(1:length(category_labels))) {
    category <- unique(codebook$category)[i]
    category_label = category_labels[i]
    cols_cat[[category_label]] <- codebook$variable_name[codebook$category == category]
  }
  return(cols_cat)
}


f_get_cols_strint <- function (dat){
  #' Function that returns a list with columnnames classified according to their type string or integer
  #' @param dat R dataframe with columns to be classified into str or int

  ### Group variables by type
  cols_binary=c()
  cols_numeric=c()
  cols_character=c()
  cols_intstr = list()
  for (col in colnames(dat)) {
    if(is.numeric(dat[[col]]) & length(unique(dat[[col]])) ==2 )  cols_binary <- c(cols_binary, col)
    if(is.numeric(dat[[col]])) cols_numeric <- c(cols_numeric, col)
    if(is.character(dat[[col]])) cols_character <- c(cols_character, col)
    
  }
  cols_intstr[['binary']] <- cols_binary
  cols_intstr[['numeric']] <- cols_numeric
  cols_intstr[['character']] <- cols_character
  return(cols_intstr)
}

p_hist_by_target <- function(dat=train_df,
                             selected_cols=cols_intstr$numeric[1:10],
                             target_var = 'diabetes_mellitus',
                             plotname="phist",
                             SAVE=FALSE){

  #' Function to make histograms given a dataframe and selected (numerical) columns
  #' @param dat R dataframe including the target and selected feature variables to plot
  #' @param selected_cols  selected (numerical) columns
  #' @param target_var name of the target variable to use for coloring
  #' @param plotname name of the plot, if not "phist" is used
  #' @param SAVE boolean to select whether to save the plot or just return the plot object

  phist <- dat %>%
    select_at(c(selected_cols, target_var)) %>%
    pivot_longer(cols = -target_var) %>%
    rename('target_var' = target_var) %>%
    ggplot(aes(x = value, fill = as.factor(target_var), group=target_var)) +
    geom_histogram() +
    facet_wrap(~name, scales = "free")+
    labs(x="Value", y="Count", fill=target_var) +
    theme(legend.position = "top")+
    scale_fill_manual(values=c("deepskyblue3","orange"))
  if(SAVE){
    if(!dir.exists(file.path("fig")))dir.create(file.path("fig"))
    ggsave(paste0(plotname,'.png'),phist, path=file.path("fig"), device = "png")
  }
  return(phist)
}

p_bar_by_target <- function(dat=train_df,
                            selected_cols=cols_intstr$character,
                            target_var = 'diabetes_mellitus',
                            plotname="pbar",
                            SAVE=FALSE){

  #' Function to make barplots given a dataframe and selected (categorical or character) columns
  #' @param dat R dataframe including the target and selected feature variables to plot
  #' @param selected_cols  selected (categorical or character) columns
  #' @param target_var name of the target variable to use for coloring
  #' @param plotname name of the plot, if not "pbar" is used
  #' @param SAVE boolean to select whether to save the plot or just return the plot object

  l = length(selected_cols)
  selected_cols <- dat  %>%
    select_at(selected_cols) %>%
    select_if(is.character) %>%
    colnames()

  print(paste0("Removed ",l - length(selected_cols)," non character variables"))

  pbar <- dat %>%
    select_at(c(selected_cols, target_var)) %>%
    pivot_longer(cols = -target_var) %>%
    rename('target_var' = target_var) %>%
    ggplot() +
    geom_bar(aes(x = value, group = target_var, fill = as.factor(target_var))) +
    facet_wrap(~name, scales = "free") +
    labs(x="Value", y="Count", fill=target_var) +
    coord_flip() +
    theme(legend.position = "top")+
    scale_fill_manual(values=c("deepskyblue3","orange"))
  if(SAVE){
    if(!dir.exists(file.path("fig")))dir.create(file.path("fig"))
    ggsave(paste0(plotname,'.png'),pbar, path=file.path("fig"), device = "png")
  }
  return(pbar)
}

f_predict_and_save_submission_csv <- function(test_dat, model_list, final_method, fname="", SAVE_DIR=""){
  #' Function to make predictions on unlabelled dataset and save submission csv
  #' @param test_dat R dataframe of the (cleaned) unlabelled data
  #' @param model_list R list object including one or more trained models for making predictions
  #' @param final_method name of the model object from the list to use, only needed of model_list has >1 model
  #' @param fname name of the submission csv, if not specified default is used
  #' @param SAVE_DIR optional specify directory to save submission csv, default "submit_csv" subfolder

  submit_df <- fread(file.path(data_dir, "SolutionTemplateWiDS2021.csv"))
  submit_df <- submit_df %>% arrange(encounter_id)

  if(length(model_list)==1){
    final_model = model_list[[1]]
    submit_df$diabetes_mellitus = predict(final_model, test_dat,type = "prob")$diabetes
  }else{
    final_model = model_list[final_method] ### Select best model
    submit_df$diabetes_mellitus = as.data.frame(predict(final_model, test_dat,type = "prob"))[,2]
  }
  
  if(SAVE_DIR==""){
    SAVE_DIR <- file.path(getwd(),"submit_csv")
  }
  
  if(!dir.exists(SAVE_DIR))dir.create(SAVE_DIR)
  if(fname=="")fname=paste0(gsub("-","",Sys.Date()),"_mr_SubmissionWiDS2021.csv")
  fwrite(submit_df,file.path(SAVE_DIR,fname))
  print(paste0("Submission csv saved under ", file.path(SAVE_DIR,fname)))
  return(submit_df)
}

impute_NA_mean <- function(coluna, class, out0, out1 ){
  out <- coluna
  for (i in 1:length(coluna)){
    
    if (is.na(coluna[i])){
      
      if (class[i] == 0){
        out[i] <- out0
        
      }else {
        out[i] <- out1
        
      }}
  }
  return(out)
}


mean_bytarget <- function(x,y){ by(x, x$diabetes_mellitus, function(y){
  mean.pl <- mean(y$d1_glucose_max, na.rm = TRUE)
})
}