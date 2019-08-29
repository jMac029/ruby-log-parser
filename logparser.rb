require 'thread'
require 'io/console'
require './model.rb'
require './view.rb'
require './controller.rb'
require './errors.rb'

@controller = LogParserController.new
@controller.run
