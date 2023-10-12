class ApiController < ActionController::API
    around_action :with_logs_context

    def index
        Rails.logger.info("Someone is calling our API.")

        render json: { greeting: "hello world" }
    end

    private

    def with_logs_context
        if user_signed_in?
            Logtail.with_context(user_context) { yield }
        else
            yield
        end
    end

    def user_context
        Logtail::Contexts::User.new(
          id: current_user.id,
          name: current_user.name,
          email: current_user.email
        )
    end

    # there's no user handling in this project, mocking one:
    def user_signed_in?
        true
    end
    def current_user
        # creating anonymous class representing user:
        Class.new do
            def id
                123
            end
            def name
                "Alice"
            end
            def email
                "alice@wonderlands.com"
            end
        end.new
    end
end
