# Functions
#install.packages('dplyr')
#install.packages('tidyr')
library(dplyr)
library(tidyr)
library(lubridate)
library(data.table)

# Set variables
path <- 'C:/Users/luizv/OneDrive_Purdue/OneDrive - purdue.edu/Spring 2023/Iza'
file_name <- 'Ceptometro_31.03.2023.csv'
final_file_name <- 'ceptometro_2023.csv'

# set path and read the csv file
setwd(path)
data_frame <- read.csv(file_name)

str(data_frame)
names(data_frame)

# Drop not used columns 
columns_drop <- c('Average.Above.PAR', 'Average.Below.PAR', 'Tau....', 'Leaf.Area.Index..LAI.', 
                  'Leaf.Distribution....', 'Beam.Fraction..Fb.', 'Zenith.Angle', 'Latitude', 'Longitude',
                  'External.Sensor.PAR', 'Record.ID', 'Raw.Record.ID')

data_frame <- data_frame[,!(names(data_frame) %in% columns_drop )]


# Replace "" values from Annotation column whit NA
data_frame$Annotation <- na_if(data_frame$Annotation, "")

# Fill in missing values with next value
data_frame <- data_frame %>% fill(Annotation, .direction = 'up')

# Delete values that still are NA in the Annotation column
data_frame <- data_frame %>% filter(!is.na(Annotation))

# Delete SUM  row (empty row)
data_frame <- subset(data_frame, Record.Type != 'SUM')

# Transform date and time from character to datetime type
number <- 0 
for (Date.and.Time in data_frame$Date.and.Time){
      
      if (number == 0){
      
            date_time_vector <- c() # empty vector to provisional storage date time values
      
      }
      
      # If date has H:M:S
      date <- dmy_hms(Date.and.Time, tz=Sys.timezone())
      
      #If date only has H:M
      if (is.na(date) == TRUE){
            
            date <- dmy_hm(Date.and.Time, tz=Sys.timezone())
            
      }
      
      date_time_vector <- append(date_time_vector, date)
      
      number = number + 1
      
}

# Replace date time values whit the new date time values stored in the date_time_vector
data_frame$Date.and.Time <- date_time_vector

# Create a new date column 
data_frame$date <- as.Date(data_frame$Date.and.Time)

# Create a column for experiment name, plot and bed
number <- 0
for (Annotation in data_frame$Annotation) {
      
      if (number == 0){
            
            experiment <- c() # create empty vector to store experiment names
            plot <- c() # create empty vector to store plot numbers
            bed <- c() # create empty vector to store bed number
            
      }
      
      exp <- strsplit(Annotation, '[_]')[[1]][1] # extract experiment characters
      
      experiment <- append(experiment,exp) # store exp characters to the vector
      
      plot_bed <- strsplit(Annotation, '[_]')[[1]][2] # extract plot and bed characters
      
      plt <- strsplit(plot_bed, '[-]')[[1]][1] # extract plot characters
      
      plot <- append(plot, plt) # store plot characters to the vector
      
      bd <- strsplit(plot_bed, '[-]')[[1]][2] # extract bed characters
      
      bed <- append(bed, bd) # store plot characters to the vector
      
      number = number + 1
      
}

# Add the new vectors as data frame columns 
data_frame$experiment <- experiment
data_frame$plot <- plot
data_frame$bed <- bed

# concatenate date experiment and plot to create a plot ID
data_frame$id_plot <- paste(data_frame$date, '_', data_frame$experiment, '_', data_frame$plot, sep = '')

# get unique experiments
experiments <- unique(data_frame$experiment)

number <- 0
for (experiment in experiments){
      
      if (number == 0){
            
            final_data_frame <- data.frame()
            
      }
      
      print('---------------------------')
      print(paste('Experiment:', experiment))
      # Subset of the experiment
      data_frame_experiment <- data_frame[data_frame$experiment == experiment,]
      
      #print(data_frame_experiment)
      
      # Get unique dates for each experiment
      dates <- unique(data_frame_experiment$date)
      
      for (date in dates){
            
            print(paste('Date:', date.mmddyy(date, sep = "/")))
            
            # Subset of the experiment and date
            data_frame_experiment_date <- data_frame_experiment[data_frame_experiment$date == date,]
            
            # get unique plot values
            plots <- unique(data_frame_experiment_date$plot)
            
            
            for (plot in plots){
                  
                  temp_data_frame_plot <- data.frame()
                  
                  print(paste('Plot:', plot))
                  
                  # Subset of the experiment, date and plot
                  data_frame_experiment_date_plot <- data_frame_experiment_date[data_frame_experiment_date$plot == plot,]
                  
                  # Get unique beds in a plot 
                  beds <- unique(data_frame_experiment_date_plot$bed)
                  
                  # Get number of beds in a plot 
                  length_beds <- length(beds)
                  
                  if (length_beds > 1){   # If the plot has more than 1 bed  run this
                        
                        
                        for (bed in beds) {
                              
                              # Select rows that belong to the specific bed
                              data_frame_experiment_date_plot_bed <- data_frame_experiment_date_plot[data_frame_experiment_date_plot$bed == bed,]
                              
                              # Create a column whit consecutive numbers since Record.Type values are not unique 
                              data_frame_experiment_date_plot_bed$Record.Type_number <- 1:nrow(data_frame_experiment_date_plot_bed)
                              
                              # Merge the beds data frame to a temporal data frame 
                              temp_data_frame_plot <- rbind(temp_data_frame_plot, data_frame_experiment_date_plot_bed)
                              
                        }

                        # Grouping and summarizing the values by plot  
                        df <- as.data.frame(temp_data_frame_plot %>% group_by(date, experiment, plot, Record.Type_number) %>% 
                                    mutate(avg = mean(c_across(Segment.1.PAR:Segment.8.PAR))) %>%
                                    select(date, experiment, plot, Record.Type_number, avg))
                        
                        df <- df[!duplicated(df), ] # Delete duplicates
                        
                        # transpose Record Type Numbers as column
                        ndf <- df %>% pivot_wider(names_from = Record.Type_number, values_from = avg) 
                        
                        # Transform tribble object to data frame
                        ndf <- as.data.frame(ndf)
                        
                        final_data_frame <- bind_rows(final_data_frame, ndf)
                        
                  } else{ # If the plot has only 1 bed  run this
                        
                        # Create a column whit consecutive numbers since Record.Type values are not unique 
                        data_frame_experiment_date_plot$Record.Type_number <- 1:nrow(data_frame_experiment_date_plot)
                        
                        # Grouping and summarizing the values by plot  
                        df <- as.data.frame(data_frame_experiment_date_plot %>% group_by(date, experiment, plot, Record.Type_number) %>% 
                                                  mutate(avg = mean(c_across(Segment.1.PAR:Segment.8.PAR))) %>%
                                                  select(date, experiment, plot, Record.Type_number, avg))
                        
                        df <- df[!duplicated(df), ] # Delete duplicates
                        
                        # transpose Record Type Numbers as column
                        ndf <- df %>% pivot_wider(names_from = Record.Type_number, values_from = avg) 
                        
                        # Transform tribble object to data frame
                        ndf <- as.data.frame(ndf)
                        
                        final_data_frame <- bind_rows(final_data_frame, ndf)
                        
                  }
                  
                  
            }
            
      }
      
      
      number = number + 1
      
}

# Create output folder if it does not exists and save the final data frame 

if (!dir.exists('./output')){
      
      dir.create('./output')
}

write.csv(new_data_frame, paste('./output/', final_file_name, sep = ''))






