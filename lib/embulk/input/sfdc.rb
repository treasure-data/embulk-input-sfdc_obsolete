module Embulk
  module Input

    class Sfdc < InputPlugin
      Plugin.register_input("sfdc", self)

      def self.transaction(config, &control)
        raise "This plugin was obsoleted."
      end

      def self.resume(task, columns, count, &control)
        raise "This plugin was obsoleted."
      end

      def self.guess(config)
        raise "This plugin was obsoleted."
      end

      def init
      end

      def run
        return {}
      end
    end

  end
end
