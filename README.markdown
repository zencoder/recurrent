Recurrent
====================
Schedule and execute your recurring tasks

Installation
------------
    gem install recurrent

Usage Examples
--------------
###Command Line
####Execute a command in the terminal
    recurrent --every 5.seconds --system "say 'Recurrent says Hello'"
####Run Ruby code
    recurrent --every 1.hour --ruby "HourlyReport.run"
####View command line options
    recurrent --help

###In your Rails app
Add `gem "recurrent"` to your Gemfile.

When `recurrent` is used from the root of your Rails application it will execute its tasks in the context of your environment and have access to your application's classes and methods.

Loading from a file
-------------------
You can define tasks and configuration info in a file.

     recurrent --file config/recurrences.rb

###The `every` method
Use the every method to create tasks.

    every 30.seconds, :collect_usage_stats, :save => true do
      Statistic.collect
    end

####Frequency
  The first argument is the frequency, it can be an integer in seconds, including ActiveSupport style 2.hours, 3.weeks etc, or an [IceCube::Schedule](http://seejohncode.com/ice_cube/)
####Name
  The second argument is the name of the task
####Options
  The third (optional) argument is options. The options are:
#####:save
  Whether or not you want to save the return value of the task. Recurrent is data store agnostic, you must configure a method by which to save the return value (see below).
#####:start_time
  The time your task should start, can be in the future or the past. If not provided it will be set based on the frequency your task is executed.
####Block
  The code you want to execute whenever the task runs.

##Configuration
  Configuration options can be set via the `configure` method in a file passed to `recurrent --file` or elsewhere in your app, such as a Rails initializer, via `Recurrent::Configuration`.

###Logging
####logger
Recurrent logs via puts, additionally you may use the logger of your choice by configuring `Recurrent::Configuration.logger` with two arguments and a block. The first argument is the message to be logged. The second is the log level, which will be one of `:info`, `:debug`, or `:warn`. An example using the Rails default logger:

      configure.logger do |message, log_level|
        RAILS_DEFAULT_LOGGER.send(log_level, message)
      end

###Keeping task execution times consistent
If you have a task that runs once an hour and you reboot your Recurrent worker 10 minutes before it was scheduled to execute you probably still want it to go off at the time it was scheduled. Letting Recurrent set your task start times partially solves this problem. For example when you create a task that runs every hour its start time is set to the beginning of the current day, and thus runs every hour on the hour. If your task runs every 5 seconds its start time will be set to the beginning of the current minute, and will execute at :00, :05, :10 etc.

Task frequencies that don't line up nicely like this will get out of sync. For example a task that is set to run every 23 hours with a start time of midnight will run at 11pm the first day, 10 pm the second day, 9pm the third day etc, but if your Recurrent worker is restarted it will start that process over. To avoid this you need to save your schedules so they can persist between reboots. Recurrent is datastore agnostic so you will need to configure the method by which you will save and load your tasks. If the following methods are configured Recurrent will keep your task execution times consistent.

####save\_task\_schedule
This method is passed the name of the task being saved, and the schedule which is an instance of [IceCube::Schedule](http://seejohncode.com/ice_cube/). Note that the schedule has a `to_yaml` method. In the block you'll put the code that saves it to your datastore of choice, to later be retrieved by `load_task_schedule`.

     configure.save_task_schedule do |name, schedule|
       # Code to save the schedule
     end

####load\_task\_schedule
This method is passed the name of the task to be loaded and must return an instance of [IceCube::Schedule](http://seejohncode.com/ice_cube/). If you saved the schedule as yaml then `IceCube::Schedule.from_yaml(schedule)` may come in handy.

     configure.load_task_schedule do |name|
       # Code to load the schedule
     end

###Capturing the return value of your task
If you'd like to capture the return value of your task you'll need to configure the following method.

####save\_task\_schedule
This method is passed an options hash.

      configure.save_task_return_value do |options|
        # Code to save the return value
      end

####options
#####:name
The name of the task.
#####:return\_value
The value returned by your block when the task was executed.
#####:executed\_at
The time at which the task was executed.
#####:executed\_by
Information about the Recurrent worker that performed the task.

###Handling a slow task
When a task is scheduled to occur Recurrent first checks to see if the task is still running from a previously scheduled execution. If it is still running then Recurrent does not initiate a new run. If you'd like to anything else, for example send yourself a notification that a task which is supposed to run every 30 seconds is taking longer than 30 seconds to execute, you can configure `Recurrent::Configuration.handle_slow_task`.

####handle\_slow\_task

     configure.handle_slow_task do |name, current_time, still_running_time|
       # notification code etc here
     end

####name
The name of the task.
####current\_time
The time the task is scheduled to run at.
####still\_running\_time
The time of the scheduled run that is still executing.

###Dealing with running tasks when exiting the Recurrent worker
By default when attempting to exit the worker it will wait for all running tasks to finish before exiting.

####wait\_for\_running\_tasks\_on\_exit\_for
How long to wait before killing tasks that are still running.

     configure.wait_for_running_tasks_on_exit_for = 10.seconds

Submitting an Issue
-------------------
We use the [GitHub issue tracker](http://github.com/zencoder/recurrent/issues) to track bugs and
features. Before submitting a bug report or feature request, check to make sure it hasn't already
been submitted. You can indicate support for an existing issuse by voting it up. When submitting a
bug report, please include a [Gist](http://gist.github.com/) that includes a stack trace and any
details that may be necessary to reproduce the bug, including your gem version, Ruby version, and
operating system. Ideally, a bug report should include a pull request with failing specs.

Copyright
---------
Copyright (c) 2011 [Zencoder](http://zencoder.com)
See [LICENSE](https://github.com/zencoder/recurrent/blob/master/LICENSE.mkd) for details.
