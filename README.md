# 🟢 Pharo TODO App

**Pharo Smalltalk** (Zinc HTTP Components) で構築した TODO アプリケーション。

Pharoならではの **Live Reflection** 機能を搭載し、実行中のアプリが自分自身のクラス構造・メソッド・ソースコードをWebブラウザ上で公開します。

## スクリーンショット

### TODO App
- タスクの追加・完了・削除
- すべて / 未完了 / 完了 のフィルタリング

### 🔍 Live Reflection
- Smalltalk System Browser 風の3パネルUI
- クラス一覧 → メソッド一覧 → ソースコード表示
- スーパークラスチェーン・インスタンス変数の表示
- Smalltalkシンタックスハイライト

## 技術スタック

| レイヤー | 技術 |
|---------|------|
| 言語 | Pharo 10 (Smalltalk) |
| Web サーバー | Zinc HTTP Components (Pharo内蔵) |
| JSON | STONJSON (Pharo内蔵) |
| フロントエンド | Vanilla HTML/CSS/JavaScript |
| データストア | インメモリ (Smalltalkオブジェクト) |

## ファイル構成

```
setup-todo.st   # Pharo Smalltalk サーバー (TODO API + Reflection API)
index.html      # TODO アプリ UI
reflect.html    # Live Reflection ブラウザ UI
```

## REST API

### TODO
| Method | Path | 説明 |
|--------|------|------|
| GET | `/api/todos` | 全タスク取得 |
| POST | `/api/todos` | タスク追加 `{"title": "..."}` |
| PUT | `/api/todos/:id` | 完了トグル |
| DELETE | `/api/todos/:id` | タスク削除 |

### Reflection
| Method | Path | 説明 |
|--------|------|------|
| GET | `/api/reflect/classes` | TodoApp パッケージの全クラス |
| GET | `/api/reflect/class/:name` | クラス詳細 (メソッド・変数・継承) |
| GET | `/api/reflect/method/:class/:selector` | メソッドのソースコード |
| GET | `/api/reflect/system` | Pharo VM / イメージ情報 |

## セットアップ

```bash
# Pharo VM + Image のダウンロード
curl -sL https://get.pharo.org/100+vm | bash

# サーバー起動 (ポート 8000)
./pharo --headless Pharo.image st setup-todo.st
```

ブラウザで http://localhost:8000/ を開いてください。

## Pharo ならではのポイント

- **リフレクション**: `cls methods`, `cls instVarNames`, `cls superclass`, `method sourceCode` などのメッセージで、実行中のオブジェクトが自分自身の構造を返す
- **ライブオブジェクト**: クラス定義もメソッドもすべてが第一級オブジェクト。Web API経由でリアルタイムにイントロスペクション可能
- **イメージベース**: アプリケーション全体が1つの Pharo イメージとして存在し、DB不要でオブジェクトが永続化される
