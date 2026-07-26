module Llm
  # Wraps a credential belonging to someone else so an owner can fall back to
  # a shared pool once its own keys are exhausted. Common shapes: a platform's
  # own keys offered to accounts that haven't brought their own, a parent
  # organisation's keys shared with its teams, or a free allowance on a plan.
  #
  # It delegates the real provider/model/key but reports shared? so
  # Llm::Client tags the usage row against the *borrowing* owner. That matters
  # for capping and billing: the spend belongs to whoever benefited from the
  # call, not to whoever owns the key.
  #
  # The gem deliberately has no opinion on where the pool comes from or when
  # an owner may use it. Supply that by overriding #shared_llm_credentials on
  # the owner (see Llm::Owned), which is where a cap or an opt-in check goes.
  class SharedCredential
    def initialize(credential)
      @credential = credential
    end

    def provider = @credential.provider
    def model = @credential.model
    def api_key = @credential.api_key
    def shared? = true
  end
end
