FactoryBot.define do
  factory :content_agent_pending_change, class: "ContentAgent::PendingChange" do
    chat
    target_type { "UsesItem" }
    operation { "create" }
    payload do
      {
        "name" => "MacBook Pro",
        "slug" => "macbook-pro",
        "category" => "hardware",
        "description" => "メイン開発機",
        "published" => true
      }
    end
  end

  factory :content_agent_task_usage, class: "ContentAgent::TaskUsage" do
    chat
    task_kind { "extraction" }
    model_id { "Qwen3-Coder-30B-A3B-Instruct" }
    input_tokens { 100 }
    output_tokens { 50 }
  end
end
