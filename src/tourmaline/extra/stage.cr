module Tourmaline
  class Stage(T)
    # Annotation for creating a step from a method.
    #
    # **Example:**
    # ```
    # @[Step(:foo, initial: true)]
    # def foo_step(update)
    #   ...
    # end
    # ```
    annotation Step; end

    # The client instance this stage is attached to
    getter client : Client

    # A hash containing the steps in this stage
    getter steps = {} of String => Proc(Client, Nil)

    # The key for the currently active step
    getter current_step : String?

    # The key to use for the initial step
    getter initial_step : String?

    # True if this Stage is currently active
    getter active : Bool

    # The context for this stage
    property context : T

    # The chat id that this stage applies to If nil, this stage
    # will be usable across all chats
    property! chat_id : Int64?

    # The user id that this stage applies to If nil, this stage
    # will be usable across all users
    property! user_id : Int64?

    @first_run : Bool
    @event_handler : EventHandler
    @on_start_handlers : Array(Proc(Nil))
    @on_exit_handlers  : Array(Proc(T, Nil))
    @response_awaiter  : Proc(Update, Nil)?

    # Create a new Stage instance
    def initialize(@client : Client, *, @context : T, chat_id = nil, user_id = nil, group = nil, **handler_options)
      @chat_id = chat_id.try &.to_i64
      @user_id = user_id.try &.to_i64
      @active  = false
      @first_run  = true

      @on_start_handlers = [] of Proc(Nil)
      @on_exit_handlers  = [] of Proc(T, Nil)

      group = group ? group.to_s : Helpers.random_string(8)
      @event_handler = EventHandler.new(:update, **handler_options, group: group) do |_, update|
        handle_update(update)
      end

      register_annotations
    end

    # Create a new Stage instance and start it immediately
    def self.enter(*args, **options)
      stage = new(*args, **options)
      stage.start
    end

    # Start the current Stage, setting the given initial step as the current step
    # and adding an event handler to the client.
    def start
      raise "No steps for this stage" if @steps.empty?
      @active = true
      @client.add_event_handler(@event_handler)
      @on_start_handlers.each(&.call)
      transition(@initial_step.to_s) if @initial_step
      self
    end

    # Stop the current Stage and remove the event handler from the client.
    def exit
      @active = false
      @response_awaiter = nil
      @client.remove_event_handler(@event_handler)
      @on_exit_handlers.each(&.call(@context))
      self
    end

    # Add an event handler for the given step name using the supplied block
    def on(step, initial = false, &block : Client ->)
      on(step, block, initial)
    end

    # Add an event handler for the given event name using the supplied proc
    def on(step, proc : Client ->, initial = false)
      step = step.to_s
      if initial
        Log.warn do
          "The step has already been defined as #{@initial_step} and is now being redefined " \
          "as #{step}. This is most likely unintentional."
        end if @initial_step
        @initial_step = step
      end
      @steps[step] = proc
      self
    end

    def on_start(&block : ->)
      @on_start_handlers << block
    end

    def on_exit(&block : T ->)
      @on_exit_handlers << block
    end

    def await_response(&block : Update ->)
      @response_awaiter = block
    end

    # Set the current step to the given value
    def transition(event)
      event = event.to_s
      raise "Event does not exist" unless @steps.has_key?(event)
      @current_step = event
      @response_awaiter = nil
      @steps[@current_step].call(@client)
      self
    end

    private def handle_update(update)
      return unless @active

      if awaiter = @response_awaiter
        # Get the returned messages from the chat, but not nested ones
        messages = [update.channel_post, update.edited_channel_post, update.edited_message, update.message].compact
        return if messages.empty?
        message = messages.first

        # Ignore updates coming from this client
        return if message.from.try &.id == @client.bot.id

        # If chat_id is set, check the message chat id and make sure it matches
        if @chat_id
          return unless chat_id == message.chat.id
        end

        # If user is set, check the message from user id and make sure it matches
        if @user_id
          return unless user_id == message.from.try &.id
        end

        puts [@chat_id, @user_id, @client.bot.id, awaiter]

        awaiter.call(update) unless @first_run
        @first_run = false
      end
    end

    private def register_annotations
      {% begin %}
        {% for cls in Stage.subclasses %}
          {% for method in cls.methods %}
            {% for ann in method.annotations(Step) %}
              %name = {{ ann[:name] || ann[0] }}
              %initial = {{ !!ann[:initial] }}
              on(%name, initial: %initial, &->{{ method.name.id }}(Client))
            {% end %}
          {% end %}
        {% end %}
      {% end %}
    end
  end
end
