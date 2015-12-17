# -*- coding: utf-8 -*-

require 'reflexion/include'

$player   =
$ground   = nil
$score    = 0
$gameover = false
$left     =
$right    = false

class View
  def remove_self ()
    parent.remove self if parent
  end
  alias center_noangle center
  def center
    p, c, a = pos, center_noangle, angle
    a == 0 ? c : p + (c - p).rotate(a)
  end
end

class KeyEvent
  def left? ()
    code == 123
  end
  def right? ()
    code == 124
  end
  def space? ()
    code == 49
  end
end

setup do
  size 800, 400            # ウィンドウサイズの調整
  flow :none               # (おまじない)
  gravity 0, 9.8 * meter   # 画面下方向の重力

  root.wall.clear_fixtures # 標準でウィンドウの枠として壁が作られてしまうので除去
  add_ground               # 地面要素の追加
  add_bricks 50            # 障害物を 50 個追加
  add_coins 50             # スコアを稼ぐ用のコインを 50 個追加
  add_enemies 10           # 敵キャラを 10 体追加
  add_player               # プレイヤーキャラクタの追加
end

def add_bricks (count)
  range = place_range
  count.times do
    window.add RectShape.new {         # 矩形の障害物をウィンドウに追加
      pos rand(range), 200             # X の位置はランダム、Y の位置は上から 200 ピクセルの位置
      size *(0..1).map {rand(20..100)} # 縦・横の大きさはそれぞれ 20〜100 のランダム
      fill rand, rand, rand            # 色も RGB それぞれランダム
      dynamic true                     # 物理演算の対象であり固定されない形状
      density 1                        # 密度指定をしないと形状が回転しない
    }
  end
end

def add_coins (count)
  range = place_range
  count.times do
    window.add EllipseShape.new { # 丸のコインオブジェクトをウィンドウに追加
      pos rand(range), 100        # X の位置はランダム、Y の位置は障害物よりも上となるように 100 ピクセルの位置
      size 30                     # 縦横は 30 で固定
      fill :yellow                # コインらしく黄色に
      static true                 # 物理演算の対象にするが、コイン自体は位置固定のため static 指定
      sensor true                 # 幽霊のように他形状と重なっても衝突しない
      on :contact do              # 他の形状と接触したときの処理
        remove_self               # 自身を削除
        $score += 1               # スコアに +1
      end
    }
  end
end

def add_enemies (count)
  range = place_range
  count.times do
    window.add RectShape.new { # 矩形をウィンドウに追加
      pos rand(range), 200     # X の位置はランダム、Y の位置はコインの少し下になるように
      size 50                  # 縦横の大きさは 50 固定
      fill :red                # 敵は危険なので赤に
      static true              # 衝突の処理はしたいので物理演算対象にするが位置は動かさないので static 指定
      sensor true              # 衝突の検出のみで物体同士で反発はしない
      on :contact do |e|       # 他の物体と接触した時の処理
        $gameover = true if e.view == $player
                               # 接触相手がプレイヤーだったらゲームオーバーフラグを立てる
      end
    }
  end
end

def place_range ()
  $ground.frame.inset_by(100).tap {|f| break f.left .. f.right}
end

def add_ground ()
  $ground = window.add View.new { # 衝突判定用の形状の指定と描画は自分でやるのでただの View をウィンドウに追加
    width 10000                   # 横スクロールのゲームなので横幅を長く
    height parent.height          # 縦幅はウィンドウの高さに合わせる
    static true                   # 物理演算の対象に

    w, h = width, height
    edges = (0..w).step(5).map do |x|   # 0〜10000ピクセルの間を5ピクセル間隔で線分を追加していく
      noise = Rays.perlin(x / 100.0, 0) # Perlin ノイズを使ってデコボコに
      [x, h + noise * 30 - 50]          # noise は -1.0〜1.0 なので 30 倍することで -30.0〜30.0 に
    end
    edges = [[0, 0]] + edges + [[w, 0]] # 地面だけだと左右の端で落ちてしまうので壁も追加

    body.clear_fixtures
    body.add_edge *edges                          # 生成した点の配列を物理演算用の線形状として登録
    on :draw do |e|                               # 地面の描画処理
      e.painter.push fill: nil, stroke: :white do # ブロック内は塗り無し・白い線で描画
        lines *edges                              # 線を描画
      end
    end
  }
end

def add_player ()
  $player = window.add EllipseShape.new {
                    # プレイヤーは丸い形状
    @jump_count = 0 # 多段ジャンプの判定用

    pos 50, 50      # 初期位置
    size 30         # 幅と高さは 30
    dynamic true    # 重力にしたがって落下するので dynamic 指定
    density 1       # 密度
    friction 1      # 摩擦

    def self.jumpable? ()     # ジャンプ可能な状態かを返す
      @jump_count <= 1        # 2段ジャンプまで
    end
    def self.jump ()          # ジャンプする
      return unless jumpable? # ジャンプ不可の状況なら何もしない
      v = velocity            # その時点での速度のベクトルを取得
      v.y = -5 * meter        # Y 方向の速度を 5 メートルに
      velocity v              # 上向きの速度を設定することでジャンプさせる
      @jump_count += 1        # 多段ジャンプ 1 回消費
    end

    on :update do        # 毎フレームのプレイヤー形状の更新処理
      dir = 0
      dir -= 1 if $left  # $left, $right は Boolean
      dir += 1 if $right # ユーザの入力状況に応じて挙動を変える
      self.angular_velocity = 360 * 3 * dir
                         # 1 秒当たり 3 回転させる
    end
    on :contact_begin do # 他形状に接触したら？
      @jump_count = 0    # ジャンプのカウントをクリア
    end
  }
end

update do                                      # 毎フレームごとに呼ばれる処理
  old_x = window.root.scroll.x                 # 現在の横スクロール位置
  new_x = $player.center.x - window.width / 2  # プレイヤーの位置
  window.root.scroll_to (old_x + new_x) / 2, 0 # 上 2 つの位置を元に、プライヤーを追従するように画面をスクロールさせる
end

draw do                                # 毎フレームの描画処理
  fill :white                          # 白塗りで
  font nil, 30                         # 大きさ 30 の標準フォントで
  text "SCORE: #{$score}", 10, 10      # スコアを左上に描画
  text "#{event.fps.to_i} FPS", 10, 50 # その下に FPS も描画
  if $gameover                         # ゲームオーバーフラグが立ってたら
    fill :red                          # 赤塗りで
    font nil, 100                      # 大きさ 100 の標準フォントで
    text "GAMEOVER!", 100, 100         # ゲームオーバーを表示
  end
end

key do                              # キー入力ごとに呼ばれる処理
  next unless down? || up?          # キーの押下もしくは押上の時のみ処理したい
  $left  = down? if left?           # 左キーが押下された？
  $right = down? if right?          # 右キーが押下された？
  $player.jump   if space? && down? # スペースキーの押下だったらプライヤーをジャンプ
end

pointer do                   # タッチイベントが発生するたびに呼ばれる処理
  next unless down? || up?   # 指が触れた時と離れた時のみ処理したい
  if y < window.height / 2   # タッチ位置が画面の上半分だったら？
    $player.jump if down?    # ジャンプする
  elsif x < window.width / 2 # タッチ位置が画面下半分のさらに左半分だったら？
    $left  = down?           # 左方向に移動する
  else                       # タッチ位置が画面下半分のさらに右半分だったら？
    $right = down?           # 右方向に移動する
  end
end
