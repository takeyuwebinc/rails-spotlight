# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# サンプル記事データ
articles_data = [
  {
    title: "マルチプラネタリーな未来のためのデザインシステムの構築",
    slug: "crafting-a-design-system-for-a-multiplanetary-future",
    description: "多くの企業はビジュアルデザインにおいて先を行くことを目指していますが、Planetariaでは、人類が太陽系全体に広がる100年後でも私たちにインスピレーションを与え続けるブランドを作る必要がありました。",
    content: "<p>多くの企業はビジュアルデザインにおいて先を行くことを目指していますが、Planetariaでは、人類が太陽系全体に広がる100年後でも私たちにインスピレーションを与え続けるブランドを作る必要がありました。</p><p>正しく行うためには、未来の誰かの視点を再現する必要があると分かっていたので、クローゼットから宇宙ヘルメットを取り出し、新しいFigmaドキュメントを作成して作業に取り掛かりました。</p><h2>デザインの哲学</h2><p>私たちのデザインシステムは、以下の原則に基づいています：</p><ol><li><strong>シンプルさ</strong> - 複雑さを排除し、本質に焦点を当てる</li><li><strong>一貫性</strong> - ユーザーが学習したパターンを再利用できるようにする</li><li><strong>適応性</strong> - 異なる環境や状況に対応できるようにする</li><li><strong>未来志向</strong> - 技術の進化に合わせて成長できるようにする</li></ol><h2>コンポーネントライブラリ</h2><p>私たちのコンポーネントライブラリは、原子デザインの原則に従って構築されています。最小の単位である「アトム」から始まり、それらを組み合わせて「分子」、「有機体」、「テンプレート」、そして最終的に「ページ」を作成します。</p><p>このアプローチにより、デザインシステムの一貫性を保ちながら、新しいコンポーネントを簡単に追加できます。</p><h2>カラーパレット</h2><p>私たちのカラーパレットは、宇宙の色彩から着想を得ています。深い宇宙の黒、星の明るい白、そして惑星の鮮やかな色彩が含まれています。</p><p>各色には、アクセシビリティ基準を満たすための明暗のバリエーションがあります。</p><h2>タイポグラフィ</h2><p>私たちは、読みやすさと未来的な雰囲気のバランスを取るために、カスタムフォントを開発しました。このフォントは、異なる重力環境でも読みやすいように設計されています。</p><h2>結論</h2><p>マルチプラネタリーな未来のためのデザインシステムを構築することは、単なる視覚的な演習ではありません。それは、人類の次の大きな冒険のためのビジョンを形作ることです。</p><p>私たちのデザインシステムは、地球上だけでなく、火星、木星の衛星、そしてその先でも機能するように設計されています。それは、私たちの種が宇宙に広がるにつれて進化し、適応するでしょう。</p>",
    published_at: 1.month.ago
  },
  {
    title: "Animaginaryの紹介",
    slug: "introducing-animaginary",
    description: "AIを使用して、テキスト説明から3Dモデルを生成する新しいツールを開発しました。",
    content: "<p>今日、私たちは最新のプロジェクト「Animaginary」を発表できることを嬉しく思います。Animaginaryは、テキスト説明から詳細な3Dモデルを生成するAIツールです。</p><h2>背景</h2><p>3Dモデリングは常に時間と専門知識を必要とするプロセスでした。私たちの目標は、誰もが簡単に3Dコンテンツを作成できるようにすることでした。</p><h2>技術</h2><p>Animaginaryは、最先端の自然言語処理と3D生成AIを組み合わせています。ユーザーは自然な言語で説明を入力するだけで、AIがその説明を解釈し、詳細な3Dモデルを生成します。</p><p>例えば、「青い鱗を持つ飛ぶドラゴン」と入力すると、AIはそのイメージに合った3Dドラゴンモデルを生成します。</p><h2>特徴</h2><ul><li><strong>テキストから3D</strong> - 自然言語の説明から3Dモデルを生成</li><li><strong>リアルタイム編集</strong> - 生成されたモデルをリアルタイムで微調整</li><li><strong>エクスポート</strong> - 一般的な3Dファイル形式へのエクスポート</li><li><strong>コラボレーション</strong> - チームでのモデル共有と編集</li></ul><h2>使用例</h2><p>Animaginaryは以下のような用途に最適です：</p><ul><li>ゲーム開発</li><li>映画制作</li><li>建築ビジュアライゼーション</li><li>製品デザイン</li><li>教育</li></ul><h2>今後の展望</h2><p>これは始まりに過ぎません。今後数ヶ月で、アニメーション機能、テクスチャ生成の改善、そしてVRでの編集機能を追加する予定です。</p><p>Animaginaryを試してみたい方は、ベータプログラムにサインアップしてください。皆さんのフィードバックをお待ちしています！</p>",
    published_at: 2.weeks.ago
  },
  {
    title: "RustでのCosmosカーネルの書き直し",
    slug: "rewriting-the-cosmos-kernel-in-rust",
    description: "パフォーマンスと安全性を向上させるために、CosmosカーネルをCからRustに移行しました。その過程で学んだことを共有します。",
    content: "<h2>はじめに</h2><p>Cosmosカーネルは10年以上にわたってCで書かれてきましたが、パフォーマンスと安全性の向上のために、Rustへの移行を決定しました。この記事では、その過程で直面した課題と学んだことを共有します。</p><h2>なぜRustなのか</h2><p>Rustを選んだ理由はいくつかあります：</p><ol><li><strong>メモリ安全性</strong> - Rustのコンパイラは多くのメモリ関連のバグを防ぎます</li><li><strong>並行処理</strong> - Rustの所有権モデルは安全な並行処理を可能にします</li><li><strong>パフォーマンス</strong> - Rustは低レベル言語でありながら、高レベルの抽象化を提供します</li><li><strong>モダンなツールチェーン</strong> - Cargoなどのツールは開発プロセスを簡素化します</li></ol><h2>移行プロセス</h2><p>移行は段階的に行いました：</p><ol><li><strong>コードベースの分析</strong> - 既存のCコードを理解し、モジュールに分割</li><li><strong>コア機能の移行</strong> - 最も重要な機能から移行を開始</li><li><strong>テスト</strong> - 各モジュールの徹底的なテスト</li><li><strong>最適化</strong> - Rustの機能を活用してコードを最適化</li></ol><h2>課題と解決策</h2><h3>FFIの複雑さ</h3><p>C言語で書かれた既存のライブラリとの統合は複雑でした。Rustの外部関数インターフェース（FFI）を使用して、Cコードを安全にラップする必要がありました。</p><pre><code>extern \"C\" {
    fn legacy_function(input: *const c_char) -> *mut c_void;
}

pub fn safe_wrapper(input: &str) -> Result<Box<dyn Any>, Error> {
    let c_input = CString::new(input)?;
    unsafe {
        // Cコードの呼び出しを安全にラップ
        let result = legacy_function(c_input.as_ptr());
        // 結果の処理
    }
}</code></pre><h3>パフォーマンスの最適化</h3><p>Rustは高速ですが、最適なパフォーマンスを得るためには注意深い設計が必要でした。特に、ヒープ割り当てを最小限に抑え、ゼロコストの抽象化を活用することに焦点を当てました。</p><h3>学習曲線</h3><p>チームの多くはRustの経験がなかったため、学習曲線は急でした。しかし、包括的なドキュメントと活発なコミュニティのおかげで、チームは迅速に適応できました。</p><h2>結果</h2><p>移行の結果は印象的でした：</p><ul><li><strong>30%のパフォーマンス向上</strong></li><li><strong>メモリ使用量の40%削減</strong></li><li><strong>セキュリティ関連のバグの大幅な減少</strong></li><li><strong>コードベースのサイズが25%減少</strong></li></ul><h2>教訓</h2><p>この移行から学んだ主な教訓は以下の通りです：</p><ol><li><strong>段階的に移行する</strong> - 一度にすべてを書き換えようとしないこと</li><li><strong>徹底的にテストする</strong> - 各コンポーネントを移行した後にテストすること</li><li><strong>チームをトレーニングする</strong> - 新しい言語の学習に時間を投資すること</li><li><strong>コミュニティを活用する</strong> - Rustコミュニティは非常に助けになります</li></ol><h2>結論</h2><p>RustでのCosmosカーネルの書き直しは大きな取り組みでしたが、結果は努力に見合うものでした。パフォーマンス、安全性、保守性の向上により、プロジェクトは新たな高みに達しました。</p><p>Rustへの移行を検討している他のプロジェクトにとって、この記事が参考になれば幸いです。</p>",
    published_at: 3.days.ago
  }
]

# 既存の記事を削除
Article.delete_all

# サンプル記事を作成
articles_data.each do |article_data|
  content = article_data.delete(:content)
  article = Article.create!(article_data)
  article.update(content: content)
end

puts "サンプル記事が作成されました"
