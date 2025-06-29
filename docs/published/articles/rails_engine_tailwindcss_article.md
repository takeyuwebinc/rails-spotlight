---
title: Rails Engine で tailwindcss-rails を使う方法
slug: rails-engine-tailwindcss-implementation
category: article
published_date: 2025-06-29
tags:
  - Rails
  - Engine
  - TailwindCSS
description: Rails Engineを使ったモジュラーモノリス構成において、各Engine独立したTailwindCSSを管理する実装方法を解説します。
---

## はじめに

Rails Engineを使ったモジュラーモノリス構成において、各Engine独立したTailwindCSSの管理方法について、tailwindcss-rails gemを用いた実装方法を詳しく解説します。

https://railsguides.jp/engines.html

https://github.com/rails/tailwindcss-rails

## 課題

Rails Engineでtailwindcss-railsを使う際の主要な課題：

1. **ソースファイルパスの解決**: 親アプリケーションのディレクトリから見た、TailwindCSSソースファイルのパスがEngineの配置方法によって異なる。
1. **Asset Pipeline統合**: アセット名が衝突する。
2. **本番環境ビルド**: precompileプロセスとの統合。
3. **依存関係管理**: Engine独立性の確保。

## 解決策の全体像

本記事では親アプリケーションのディレクトリ直下に `engines` ディレクトリを設け、各Engineを配置しているものとしますが、本記事で紹介する設定方法はディレクトリ配置に影響なく機能するはずです。

```
engines/
└── my_engine/
    ├── app/
    │   ├── assets/
    │   │   ├── builds/
    │   │   │   └── my_engine/
    │   │   │       └── tailwind.css         # ビルド結果
    │   │   └── tailwind/
    │   │       └── my_engine/
    │   │           └── application.css      # ソースファイル
    │   └── views/
    │       └── layouts/
    │           └── my_engine/
    │               └── application.html.erb
    ├── lib/
    │   └── tasks/
    │       └── tailwindcss_tasks.rake       # カスタムRakeタスク
    └── my_engine.gemspec            # 依存関係定義
```

## 実装手順

### 1. Engine gemspecでの依存関係設定

```ruby:engines/my_engine/my_engine.gemspec
Gem::Specification.new do |spec|
  spec.name        = "my_engine"
  spec.version     = "0.1.0"
  # ...

  spec.add_dependency "rails", ">= 8.0.2"
  spec.add_dependency "tailwindcss-rails", ">= 4.2.3"
end
```

### 2. TailwindCSSソースファイルの作成

メインアプリケーションでは `app/assets/tailwind/application.css` というファイル名にしますが、Engineで使う場合は、 `app/assets/tailwind/my_engine/application.css` というように**Engineを示す名前をパスに含める**と便利です。アセット名としてEngineを含むようにした方が、衝突を気にせずに済むためです。

```css:engines/my_engine/app/assets/tailwind/my_engine/application.css
@import "tailwindcss";
@plugin "@tailwindcss/typography";
```

### 3. ビルド用のカスタムRakeタスクの実装

EngineのTailwindCSSビルド用のRakeタスクを作成し、 `app/assets/tailwind/my_engine/application.css` から `app/assets/builds/my_engine/tailwind.css` を作成できるようにします。

```bash
# 実行イメージ
$ bin/rails tailwindcss:my_engine:build
$ bin/rails tailwindcss:my_engine:watch
```

作成した `tailwindcss:my_engine:build` タスクを、`bin/rails assets:precompile` の事前タスクとして指定することで、プリコンパイルの直前に、EngineのTailwindCSSのRakeタスクが実行されるようになり、プリコンパイル結果にビルド結果が含まれるようになります。

```ruby:engines/my_engine/lib/tasks/tailwindcss_tasks.rake
require "tailwindcss-rails"

namespace :tailwindcss do
  namespace :my_engine do
    desc "Build Tailwind CSS for MyEngine engine"
    task :build do
      command = [
        Tailwindcss::Ruby.executable.to_s,
        "--input", MyEngine::Engine.root.join("app/assets/tailwind/my_engine/application.css").to_s,
        "--output", MyEngine::Engine.root.join("app/assets/builds/my_engine/tailwind.css").to_s,
        "--cwd", Rails.root.to_s
      ]

      # Add minification in production
      command << "--minify" if Rails.env.production?

      system(*command, exception: true)
    end

    desc "Watch and build Tailwind CSS for MyEngine engine"
    task :watch do
      command = [
        Tailwindcss::Ruby.executable.to_s,
        "--input", MyEngine::Engine.root.join("app/assets/tailwind/my_engine/application.css").to_s,
        "--output", MyEngine::Engine.root.join("app/assets/builds/my_engine/tailwind.css").to_s,
        "--cwd", Rails.root.to_s,
        "--watch"
      ]

      puts "Watching MyEngine Tailwind CSS..."
      system(*command)
    end
  end
end

# assets:precompileタスクに統合
# プリコンパイルの直前にEngineのTailwindCSSビルドを実行する。
Rake::Task["assets:precompile"].enhance([ "tailwindcss:my_engine:build" ])
```

:::message
各Engineの `app/assets` 以下のディレクトリ（たとえば `builds`）は、自動でアセットのパス `Rails.application.assets.config.paths` に追加される為、特別な設定は不要です。
:::

### 4. レイアウトファイルでの読み込み

`stylesheet_link_tag` ヘルパーに渡すアセット名は、 `app/assets/builds` 以下のファイルパスになります。

```html:engines/my_engine/app/views/layouts/my_engine/application.html.erb
<!DOCTYPE html>
<html>
<head>
  <title>MyEngine</title>
  <%= csrf_meta_tags %>
  <%= csp_meta_tag %>

  <%= stylesheet_link_tag "my_engine/tailwind" %>
</head>
<body>
  <div class="container mx-auto">
    <!-- TailwindCSSのクラスが使用可能 -->
    <% if notice %>
      <div class="bg-green-100 border border-green-400 text-green-700 px-4 py-3 rounded mb-4" role="alert">
        <span class="block sm:inline"><%= notice %></span>
      </div>
    <% end %>
    
    <%= yield %>
  </div>
</body>
</html>
```

### 5. 開発環境の設定

メインアプリケーションの `bin/dev` で開発サーバーと同時に、EngineのTailwindCSSの監視とビルドのためのタスクを起動するようにします。

```plaintext:Procfile.dev
web: bin/rails server -b 0.0.0.0
my_engine_css: bin/rails tailwindcss:my_engine:watch
```

### 6. .gitignore設定

Engine内のビルド結果をコミットに含めないように無視設定を追加します。

```plaintext:engines/my_engine/.gitignore
/app/assets/builds/*
!/app/assets/builds/.keep
```

## 重要なポイント

### Engine.root の活用

TailwindCSSソースファイルのパスを、Engineのパスからの相対パスで取得します。

```ruby
MyEngine::Engine.root.join("app/assets/tailwind/my_engine/application.css").to_s
```

### Asset Pipeline統合

ビルド結果を `app/assets/builds/` ディレクトリに配置することで、Rails Asset Pipelineが自動的にファイルを認識・配信します。

ビルド結果のパスにEngine（ `my_engine` ）を含めることで、親アプリケーションの同名のファイルと衝突することを防ぎます。

メインアプリケーション:

- `app/assets/tailwind/application.css`
- `app/assets/builds/tailwind.css`

Engine:

- `app/assets/tailwind/my_engine/application.css`
- `app/assets/builds/my_engine/tailwind.css`

### 本番環境での自動ビルド

```ruby
Rake::Task["assets:precompile"].enhance([ "tailwindcss:my_engine:build" ])
```

この設定により、`assets:precompile` 実行時に自動的にEngineのTailwindCSSがビルドされます。

## 複数Engineでの運用

複数のEngineで同様の構成を採用する場合：

```plaintext:Procfile.dev
web: bin/rails server -b 0.0.0.0
my_engine_css: bin/rails tailwindcss:my_engine:watch
my_admin_engine_css: bin/rails tailwindcss:my_admin_engine:watch
```

各Engine独立してTailwindCSSを管理できるため、スタイルの競合を避けながら効率的な開発が可能です。

## まとめ

この実装方法により、以下の利点が得られます：

- **Engine独立性**: 各Engineが独自のTailwindCSS設定を管理
- **Rails統合**: 標準的なAsset Pipelineとの完全統合
- **本番対応**: 自動化されたビルドプロセス
- **保守性**: 明確な設定分離と構造化

Rails Engineを使ったモジュラーモノリス構成において、この手法を用いることで、Engineごとに独立したスタイルを容易に管理可能になり、Railsアプリケーション全体の保守性向上に貢献します。
