# BundleIDGuard

起動中アプリの **Bundle ID が許可リストと一致するか** を確認する、小さな iOS 用 dylib です。
一致しない場合はアラートを表示し、OK を押すとアプリを終了します。

- 許可する Bundle ID はビルド時に指定(複数指定可)
- GitHub Actions でビルドできる(手元に Mac や Xcode は不要)
- ソースコードは `BundleIDGuard.m` の1ファイルのみ

> **ご利用について**
> 自分で開発・配布しているアプリ、または改変や利用の許可を得ているアプリに対してのみ使用してください。

---

## 特徴

| 項目 | 内容 |
| --- | --- |
| 対応アーキテクチャ | arm64 |
| 最低 iOS バージョン | 13.0(`build.yml` で変更可) |
| 依存フレームワーク | Foundation / UIKit / JavaScriptCore |
| 判定方法 | 許可リストとの完全一致(大文字小文字を区別) |
| 不一致時の動作 | アラート表示 → OK でアプリ終了 |

---

## 使い方

### 1. このリポジトリをフォークする

ページ右上の **Fork** を押して、自分のアカウントにコピーします。

### 2. 許可する Bundle ID を設定する

リポジトリ直下の `bundle_id.txt` を編集します。1行目に Bundle ID を書き、複数ならカンマ区切りにします。

```
com.example.app
```

```
com.example.app,com.example.app2
```

### 3. ビルドする

ビルド方法は2通りあります。

| ビルド方法 | Bundle ID の指定先 |
| --- | --- |
| 自動(`main` ブランチへの push) | `bundle_id.txt` の1行目 |
| 手動(Actions タブ → Run workflow) | 入力欄。空欄なら `bundle_id.txt` |

**自動ビルド**: `bundle_id.txt` を編集してコミットするだけで、ビルドが始まります。

**手動ビルド**:
1. **Actions** タブを開きます。
2. 左の一覧から **Build BundleIDGuard** を選びます。
3. **Run workflow** を押し、必要なら Bundle ID を入力して実行します。

> フォークしたリポジトリでは、最初に Actions タブで「ワークフローを有効にする」ボタンを押す必要があります。

### 4. dylib を取得する

1. ビルドが完了した実行ページを開きます。
2. ページ下部の **Artifacts** から `BundleIDGuard` をダウンロードします(GitHub へのログインが必要です)。
3. 解凍すると `BundleIDGuard.dylib` が入っています。

ビルドログの `Allowed Bundle ID: ...` の行で、実際に埋め込まれた値を確認できます。

---

## 動作

1. アプリの起動完了後に、`NSBundle.mainBundle.bundleIdentifier` を取得します。
2. 許可リストに含まれていれば、何もせず通常どおり動作します。
3. 含まれていなければ、次の動作をします。
   - アラートを表示します(現在の Bundle ID も表示されます)。
   - **OK** を押すとアプリを終了します。

画面がまだ出ていない起動直後は、0.5 秒間隔で最大 20 回アラートの表示を再試行します。それでも表示できなければ、そのままアプリを終了します。

### ログ

ログは `[BundleIDGuard]` で始まります。

| ログ | 意味 |
| --- | --- |
| `Tweak loaded successfully` | dylib が読み込まれた |
| `OK (<bundle id>)` | Bundle ID が一致した |
| `Bundle ID mismatch! expected=..., actual=...` | 不一致を検出した |
| `Terminating app due to Bundle ID mismatch` | アプリを終了する |

---

## JavaScriptCore からの上書き

`JSExport` に対応しているので、JavaScriptCore 経由で許可リストを実行時に上書きできます。

```javascript
Bundleid("com.example.app,com.example.app2");
```

---

## カスタマイズ

`BundleIDGuard.m` を編集します。

| 変更したい内容 | 場所 |
| --- | --- |
| アラートのタイトル・本文 | `showAlertWithActual:` 内の文字列 |
| ボタンの文言・スタイル | 同じく `UIAlertAction` の部分 |
| アラート再試行の回数・間隔 | `retries > 20` と `0.5 * NSEC_PER_SEC` |
| 最低対応 iOS バージョン | `.github/workflows/build.yml` の `-miphoneos-version-min=13.0` |

---

## トラブルシューティング

| 症状 | 確認すること |
| --- | --- |
| 自動でビルドが走らない | フォークの場合、Actions を有効にしたか。`build.yml` が `.github/workflows/` 内にあるか |
| Bundle ID が `com.example.app` のまま | `bundle_id.txt` がリポジトリ直下にあるか。1行目に書いているか |
| 手動実行で入力欄が出ない | `build.yml` に `workflow_dispatch` の `inputs` があるか |
| 許可したはずなのにアラートが出る | ログの `expected=` と `actual=` を見比べる。大文字小文字も区別されます |
| ビルドエラーが出る | Actions のログを添えて Issue を立ててください |

---

## 制限事項

- 判定は、ビルド時に埋め込んだ文字列との**完全一致**です(前方一致・部分一致は不可)。
- アプリの利用範囲を確認する簡易的な仕組みです。改ざん対策などの強固な保護には向きません。

---

## ファイル構成

```
.
├─ BundleIDGuard.m              # dylib 本体のソースコード
├─ bundle_id.txt                # 許可する Bundle ID
├─ README.md                    # このファイル
└─ .github/
   └─ workflows/
      └─ build.yml              # GitHub Actions のビルド設定
```

---

## ライセンス

`LICENSE` ファイルを参照してください。

## 不具合報告・要望

[Issues](../../issues) からお願いします。
