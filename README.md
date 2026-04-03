# ✅ Pharo TODO App

**Pharo Smalltalk** (Zinc HTTP Components) で構築した TODO アプリケーション。

Pharoならではの **Live Reflection** と **ライブ編集・コンパイル** 機能を搭載。
実行中のアプリのクラス・メソッド・ソースコードを閲覧できるだけでなく、
**ブラウザ上からメソッドを書き換えて、再起動なしで即座に動作を変更**できます。

## 主な機能

### TODO アプリ
- タスクの追加・完了トグル・削除
- すべて / 未完了 / 完了 のフィルタリング
- 日本語 IME 対応（変換確定時の誤送信防止）

### 🔍 Live Reflection
- TODO画面の下部に統合表示（別ページ不要）
- Classes → Methods → Source Code の3パネル構成
- スーパークラスチェーン・インスタンス変数・クラス変数の表示

### ⚡ ライブ編集・コンパイル
- ソースコードをテキストエリアで直接編集
- 「保存 (Ctrl+S)」で実行中の Pharo イメージに即座にコンパイル反映
- **サーバー再起動不要** — 変更は即座に次のAPIリクエストから有効
- ワンクリックデモ:
  - **★ タイトルに★を付ける** — `asDictionary` を変更して全タスク名に★プレフィックス
  - **🔠 タイトルを大文字に** — `title asUppercase` に書き換え
  - **↩ 元に戻す** — オリジナルに復元

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
setup-todo.st   # Pharo Smalltalk サーバー (TODO API + Reflection API + Compile API)
index.html      # 単一ページUI (TODO + Live Reflection + デモ)
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
| POST | `/api/reflect/compile` | メソッドのライブコンパイル `{"class": "...", "source": "...", "side": "instance"}` |

## セットアップ

```bash
# Pharo VM + Image のダウンロード
curl -sL https://get.pharo.org/100+vm | bash

# サーバー起動 (ポート 8000)
./pharo --headless Pharo.image st setup-todo.st
```

ブラウザで http://localhost:8000/ を開いてください。

## データについて

データはメモリ上のみで保持されます。サーバー再起動で空になります。

## Pharo ならではのポイント

- **リフレクション**: `cls methods`, `cls instVarNames`, `method sourceCode` などで実行中のオブジェクトが自分自身の構造を返す
- **ライブコンパイル**: `cls compile: 'newSource'` で実行中のメソッドを即座に差し替え — 再起動不要
- **ライブオブジェクト**: クラスもメソッドもすべてが第一級オブジェクト。Web API経由でリアルタイムに閲覧・変更が可能
- **イメージベース**: アプリケーション全体が1つの Pharo イメージとして存在し、DB不要でオブジェクトがメモリ上に生きている
