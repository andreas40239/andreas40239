package de.andreas40239.hopquest

import android.content.Context
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.view.MotionEvent
import android.view.SurfaceHolder
import android.view.SurfaceView
import kotlin.math.min

private enum class GameState { MENU, PLAYING, GAME_OVER }
private enum class Scenery { MOUNTAINS, UNDERGROUND, SEA }

class GameView(context: Context) : SurfaceView(context), SurfaceHolder.Callback, Runnable {

    // ---- thread / loop ----
    private var thread: Thread? = null
    @Volatile private var running = false
    private val holder2: SurfaceHolder = holder

    private val prefs: SharedPreferences =
        context.getSharedPreferences("hopquest", Context.MODE_PRIVATE)

    private val audio = GameAudio(context)

    // ---- source bitmaps (decoded once) ----
    private val srcIdle = decode(R.drawable.char_idle)
    private val srcRun1 = decode(R.drawable.char_run1)
    private val srcRun2 = decode(R.drawable.char_run2)
    private val srcJump = decode(R.drawable.char_jump)
    private val srcHit = decode(R.drawable.char_hit)
    private val srcHeartFull = decode(R.drawable.heart_full)
    private val srcHeartEmpty = decode(R.drawable.heart_empty)

    private val srcBg = mapOf(
        Scenery.MOUNTAINS to decode(R.drawable.bg_mountains),
        Scenery.UNDERGROUND to decode(R.drawable.bg_underground),
        Scenery.SEA to decode(R.drawable.bg_sea),
    )
    private val srcObstacle = mapOf(
        Scenery.MOUNTAINS to decode(R.drawable.obstacle_mountains),
        Scenery.UNDERGROUND to decode(R.drawable.obstacle_underground),
        Scenery.SEA to decode(R.drawable.obstacle_sea),
    )
    private val srcFly = mapOf(
        Scenery.MOUNTAINS to listOf(decode(R.drawable.fly_mountains_0), decode(R.drawable.fly_mountains_1)),
        Scenery.UNDERGROUND to listOf(decode(R.drawable.fly_underground_0), decode(R.drawable.fly_underground_1)),
        Scenery.SEA to listOf(decode(R.drawable.fly_sea_0), decode(R.drawable.fly_sea_1)),
    )
    private val sceneryLabel = mapOf(
        Scenery.MOUNTAINS to "Berge & Wiesen",
        Scenery.UNDERGROUND to "Unter der Erde",
        Scenery.SEA to "Am Meer",
    )

    private fun decode(id: Int): Bitmap =
        BitmapFactory.decodeResource(resources, id, BitmapFactory.Options().apply { inScaled = false })

    // ---- scaled/cached per-surface-size assets ----
    private var canvasW = 0
    private var canvasH = 0
    private var scaledBg: MutableMap<Scenery, Bitmap> = mutableMapOf()
    private var scaledBgWidth = 0f
    private var scaledObstacle: MutableMap<Scenery, Bitmap> = mutableMapOf()
    private var scaledFly: MutableMap<Scenery, List<Bitmap>> = mutableMapOf()
    private var playerFrames: List<Bitmap> = emptyList() // idle, run1, run2, jump, hit (scaled)
    private var heartFullScaled: Bitmap? = null
    private var heartEmptyScaled: Bitmap? = null
    private var heartPickupScaled: Bitmap? = null

    private var groundY = 0f
    private var playerX = 0f
    private var playerW = 0f
    private var playerH = 0f

    // ---- world constants (fractions of canvas height / resolution independent) ----
    private val gravityFrac = 3.6f      // * canvasH -> px/s^2
    private val jumpVelFrac = 1.55f     // * canvasH -> px/s
    private val baseSpeedFrac = 0.55f
    private val maxSpeedFrac = 1.8f
    private val speedGrowTime = 120f
    private val baseObstacleHFrac = 0.11f
    private val maxObstacleHFrac = 0.24f
    private val obstacleGrowTime = 100f
    private val jumpAirTime get() = 2f * jumpVelFrac / gravityFrac

    // flying obstacles sit well above standing head-height so a grounded player
    // always clears them — only jumping into their band causes a hit
    private val flyHFrac = 0.10f
    private val flyBottomOffsetFrac = 0.38f // above groundY
    private val flyBobAmplitudeFrac = 0.015f
    private val flyMinIntervalSeconds = 4.5f
    private val flyMaxIntervalSeconds = 8f

    // heart pickups
    private val heartPickupSizeFrac = 0.09f
    private val heartSpawnIntervalSeconds = 10f
    private val startingLives = 3
    private val maxLives = 5

    // shared fairness guard: never let a ground obstacle and a flying obstacle
    // arrive at the player at nearly the same time (that would be unavoidable)
    private val dangerWindowSeconds = 0.9f

    // ---- game state ----
    private var state = GameState.MENU
    private var scenery = Scenery.MOUNTAINS
    private var lives = startingLives
    private var survivalTime = 0f
    private var score = 0
    private var bestScore = prefs.getInt("best_score", 0)
    private var newBestAchieved = false

    private var playerY = 0f
    private var velY = 0f
    private var grounded = true
    private var invulnTimer = 0f
    private var animTimer = 0f
    private var animFrame = 0

    private val obstacles = Array(8) { Obstacle() }
    private var spawnTimer = 0f
    private val flyingObstacles = Array(4) { FlyingObstacle() }
    private var flyingSpawnTimer = 0f
    private val heartPickups = Array(2) { HeartPickup() }
    private var heartSpawnTimer = 0f
    private var bgOffset = 0f

    private var lastNanos = 0L

    // ---- menu card layout ----
    private var cards: List<RectF> = emptyList()
    private val sceneryOrder = listOf(Scenery.MOUNTAINS, Scenery.UNDERGROUND, Scenery.SEA)

    // ---- paints (created once) ----
    private val scorePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE
        textAlign = Paint.Align.RIGHT
        setShadowLayer(6f, 0f, 2f, Color.parseColor("#66000000"))
    }
    private val labelPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE
        textAlign = Paint.Align.CENTER
        setShadowLayer(6f, 0f, 2f, Color.parseColor("#88000000"))
    }
    private val titlePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE
        textAlign = Paint.Align.CENTER
        setShadowLayer(8f, 0f, 3f, Color.parseColor("#99000000"))
    }
    private val bigScorePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE
        textAlign = Paint.Align.CENTER
        setShadowLayer(10f, 0f, 4f, Color.parseColor("#AA000000"))
    }
    private val overlayPaint = Paint().apply { color = Color.parseColor("#99000000") }
    private val cardBgPaint = Paint().apply { color = Color.parseColor("#33000000") }
    private val cardBorderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = 6f
        color = Color.WHITE
    }
    private val cardSelectedBorderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = 12f
        color = Color.parseColor("#FFD54F")
    }

    init {
        holder2.addCallback(this)
        isFocusable = true
    }

    // ---------------------------------------------------------------
    // SurfaceHolder.Callback
    // ---------------------------------------------------------------
    override fun surfaceCreated(holder: SurfaceHolder) {
        startLoop()
    }

    override fun surfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) {
        canvasW = width
        canvasH = height
        rebuildScaledAssets()
        layoutMenuCards()
        groundY = canvasH * 0.83f
        if (state == GameState.MENU) {
            // keep player idle preview centered-ish; nothing else to do
        }
    }

    override fun surfaceDestroyed(holder: SurfaceHolder) {
        stopLoop()
    }

    private fun rebuildScaledAssets() {
        if (canvasH <= 0) return
        playerH = canvasH * 0.22f
        playerW = playerH * (srcIdle.width.toFloat() / srcIdle.height.toFloat())
        playerX = canvasW * 0.16f

        playerFrames = listOf(srcIdle, srcRun1, srcRun2, srcJump, srcHit).map {
            Bitmap.createScaledBitmap(it, playerW.toInt().coerceAtLeast(1), playerH.toInt().coerceAtLeast(1), true)
        }

        val heartSize = canvasH * 0.07f
        heartFullScaled = Bitmap.createScaledBitmap(srcHeartFull, heartSize.toInt(), heartSize.toInt(), true)
        heartEmptyScaled = Bitmap.createScaledBitmap(srcHeartEmpty, heartSize.toInt(), heartSize.toInt(), true)

        val pickupSize = (canvasH * heartPickupSizeFrac).toInt().coerceAtLeast(1)
        heartPickupScaled = Bitmap.createScaledBitmap(srcHeartFull, pickupSize, pickupSize, true)

        scaledBg.clear()
        for ((k, bmp) in srcBg) {
            val w = (canvasH.toFloat() * bmp.width / bmp.height).toInt().coerceAtLeast(1)
            scaledBg[k] = Bitmap.createScaledBitmap(bmp, w, canvasH, true)
        }
        scaledBgWidth = scaledBg.values.first().width.toFloat()

        scaledObstacle.clear() // rebuilt lazily per-size in getObstacleBitmap via cache below
        obstacleBitmapCache.clear()

        val flyH = (canvasH * flyHFrac).toInt().coerceAtLeast(1)
        scaledFly.clear()
        for ((k, frames) in srcFly) {
            scaledFly[k] = frames.map { f ->
                val w = (flyH.toFloat() * f.width / f.height).toInt().coerceAtLeast(1)
                Bitmap.createScaledBitmap(f, w, flyH, true)
            }
        }

        scorePaint.textSize = canvasH * 0.075f
        labelPaint.textSize = canvasH * 0.055f
        titlePaint.textSize = canvasH * 0.09f
        bigScorePaint.textSize = canvasH * 0.11f
    }

    private fun layoutMenuCards() {
        val margin = canvasW * 0.04f
        val gap = canvasW * 0.03f
        val cardW = (canvasW - margin * 2 - gap * 2) / 3f
        val cardH = canvasH * 0.56f
        val top = canvasH * 0.20f
        cards = (0 until 3).map { i ->
            val left = margin + i * (cardW + gap)
            RectF(left, top, left + cardW, top + cardH)
        }
    }

    // ---------------------------------------------------------------
    // lifecycle
    // ---------------------------------------------------------------
    fun onResume() {
        startLoop()
        if (state == GameState.PLAYING) audio.resumeMusic()
    }

    fun onPause() {
        stopLoop()
        audio.pauseMusic()
    }

    private fun startLoop() {
        if (thread?.isAlive == true) return
        running = true
        lastNanos = System.nanoTime()
        thread = Thread(this, "GameLoop").also { it.start() }
    }

    private fun stopLoop() {
        running = false
        thread?.let {
            try { it.join(300) } catch (_: InterruptedException) {}
        }
        thread = null
    }

    // ---------------------------------------------------------------
    // main loop
    // ---------------------------------------------------------------
    override fun run() {
        while (running) {
            val now = System.nanoTime()
            var dt = (now - lastNanos) / 1_000_000_000f
            lastNanos = now
            if (dt > 0.05f) dt = 0.05f // clamp to avoid spiral of death after a stall

            update(dt)

            val canvas = try { holder2.lockCanvas() } catch (_: Exception) { null }
            if (canvas != null) {
                try {
                    synchronized(holder2) { renderFrame(canvas) }
                } finally {
                    try { holder2.unlockCanvasAndPost(canvas) } catch (_: Exception) {}
                }
            }

            // simple frame pacing towards ~60fps without busy spinning
            val frameNanos = System.nanoTime() - now
            val targetNanos = 16_666_667L
            val sleepMs = (targetNanos - frameNanos) / 1_000_000L
            if (sleepMs > 0) {
                try { Thread.sleep(sleepMs) } catch (_: InterruptedException) {}
            }
        }
    }

    // ---------------------------------------------------------------
    // update
    // ---------------------------------------------------------------
    private fun update(dt: Float) {
        if (canvasH <= 0) return
        if (state != GameState.PLAYING) return

        survivalTime += dt
        score = survivalTime.toInt()

        val speed = currentSpeed()
        bgOffset = (bgOffset + speed * 0.8f * dt) % scaledBgWidth

        // player physics
        val gravity = gravityFrac * canvasH
        velY += gravity * dt
        playerY += velY * dt
        if (playerY + playerH >= groundY) {
            playerY = groundY - playerH
            velY = 0f
            grounded = true
        } else {
            grounded = false
        }

        if (invulnTimer > 0f) invulnTimer -= dt

        // animation
        animTimer += dt
        if (grounded) {
            if (animTimer > 0.12f) {
                animTimer = 0f
                animFrame = if (animFrame == 1) 2 else 1
            }
        } else {
            animFrame = 3
        }

        updateObstacles(dt, speed)
        updateFlyingObstacles(dt, speed)
        updateHeartPickups(dt, speed)
    }

    private fun currentSpeed(): Float {
        val t = min(survivalTime / speedGrowTime, 1f)
        return (baseSpeedFrac + (maxSpeedFrac - baseSpeedFrac) * t) * canvasH
    }

    private fun currentObstacleHeight(): Float {
        val t = min(survivalTime / obstacleGrowTime, 1f)
        return (baseObstacleHFrac + (maxObstacleHFrac - baseObstacleHFrac) * t) * canvasH
    }

    private fun updateObstacles(dt: Float, speed: Float) {
        for (o in obstacles) {
            if (!o.active) continue
            o.x -= speed * dt
            if (o.right() < -20f) {
                o.active = false
                continue
            }
            checkCollision(o)
        }

        spawnTimer -= dt
        if (spawnTimer <= 0f) {
            spawnObstacle(speed)
        }
    }

    private fun spawnObstacle(speed: Float) {
        val free = obstacles.firstOrNull { !it.active }
        val h = currentObstacleHeight()
        val srcObs = srcObstacle.getValue(scenery)
        val w = h * (srcObs.width.toFloat() / srcObs.height.toFloat())
        val spawnX = canvasW.toFloat() + w
        val candidateArrival = arrivalTime(spawnX, speed)

        if (free == null || !flyingObstaclesClearAt(candidateArrival, speed)) {
            spawnTimer = 0.4f // retry shortly rather than force an unfair overlap
            return
        }

        free.spawn(spawnX, w, h)
        val minGap = speed * jumpAirTime * 1.4f
        val extra = speed * jumpAirTime * (0.3f + Math.random().toFloat() * 0.7f)
        val distance = minGap + extra
        spawnTimer = distance / speed
    }

    /** Seconds until an object at world-x `x` (moving at `speed`) reaches the player. */
    private fun arrivalTime(x: Float, speed: Float) = (x - (playerX + playerW)) / speed

    private fun flyingObstaclesClearAt(candidateArrival: Float, speed: Float): Boolean {
        for (o in flyingObstacles) {
            if (!o.active) continue
            val t = arrivalTime(o.x, speed)
            if (t > -0.3f && kotlin.math.abs(t - candidateArrival) < dangerWindowSeconds) return false
        }
        return true
    }

    private fun groundObstaclesClearAt(candidateArrival: Float, speed: Float): Boolean {
        for (o in obstacles) {
            if (!o.active) continue
            val t = arrivalTime(o.x, speed)
            if (t > -0.3f && kotlin.math.abs(t - candidateArrival) < dangerWindowSeconds) return false
        }
        return true
    }

    private fun updateFlyingObstacles(dt: Float, speed: Float) {
        for (o in flyingObstacles) {
            if (!o.active) continue
            o.x -= speed * dt
            o.bobPhase += dt * 4f
            if (o.right() < -20f) {
                o.active = false
                continue
            }
            checkFlyingCollision(o)
        }

        flyingSpawnTimer -= dt
        if (flyingSpawnTimer <= 0f) spawnFlyingObstacle(speed)
    }

    private fun spawnFlyingObstacle(speed: Float) {
        val free = flyingObstacles.firstOrNull { !it.active }
        val srcF = srcFly.getValue(scenery)[0]
        val h = canvasH * flyHFrac
        val w = h * (srcF.width.toFloat() / srcF.height.toFloat())
        val spawnX = canvasW.toFloat() + w
        val candidateArrival = arrivalTime(spawnX, speed)

        if (free == null || !groundObstaclesClearAt(candidateArrival, speed)) {
            flyingSpawnTimer = 0.4f
            return
        }

        val y = groundY - flyBottomOffsetFrac * canvasH - h
        free.spawn(spawnX, y, w, h)
        flyingSpawnTimer = flyMinIntervalSeconds + Math.random().toFloat() * (flyMaxIntervalSeconds - flyMinIntervalSeconds)
    }

    private fun checkFlyingCollision(o: FlyingObstacle) {
        if (o.hasHit) return
        if (invulnTimer > 0f) return
        val pLeft = playerX + playerW * 0.22f
        val pRight = playerX + playerW * 0.82f
        val pTop = playerY + playerH * 0.15f
        val pBottom = playerY + playerH * 0.98f
        val oY = o.currentY(canvasH * flyBobAmplitudeFrac)
        val overlap = pRight > o.x && pLeft < o.right() && pBottom > oY && pTop < oY + o.height
        if (overlap) {
            o.hasHit = true
            onPlayerHit()
        }
    }

    private fun updateHeartPickups(dt: Float, speed: Float) {
        for (h in heartPickups) {
            if (!h.active) continue
            h.x -= speed * dt
            if (h.right() < -20f) {
                h.active = false
                continue
            }
            checkHeartCollision(h)
        }

        heartSpawnTimer -= dt
        if (heartSpawnTimer <= 0f) spawnHeartPickup(speed)
    }

    private fun spawnHeartPickup(speed: Float) {
        val free = heartPickups.firstOrNull { !it.active }
        val size = canvasH * heartPickupSizeFrac
        val spawnX = canvasW.toFloat() + size
        val candidateArrival = arrivalTime(spawnX, speed)

        if (free == null || !groundObstaclesClearAt(candidateArrival, speed)) {
            heartSpawnTimer = 0.5f
            return
        }

        val y = groundY - playerH * 0.62f - size / 2f
        free.spawn(spawnX, y, size)
        heartSpawnTimer = heartSpawnIntervalSeconds
    }

    private fun checkHeartCollision(h: HeartPickup) {
        val pLeft = playerX + playerW * 0.22f
        val pRight = playerX + playerW * 0.82f
        val pTop = playerY + playerH * 0.15f
        val pBottom = playerY + playerH * 0.98f
        val overlap = pRight > h.x && pLeft < h.right() && pBottom > h.y && pTop < h.y + h.size
        if (overlap) {
            h.active = false
            audio.playPickup()
            if (lives < maxLives) lives += 1
        }
    }

    private fun checkCollision(o: Obstacle) {
        if (o.hasHit) return
        if (invulnTimer > 0f) return
        val pLeft = playerX + playerW * 0.22f
        val pRight = playerX + playerW * 0.82f
        val pTop = playerY + playerH * 0.15f
        val pBottom = playerY + playerH * 0.98f
        val oLeft = o.x
        val oRight = o.right()
        val oTop = groundY - o.height
        val oBottom = groundY
        val overlap = pRight > oLeft && pLeft < oRight && pBottom > oTop && pTop < oBottom
        if (overlap) {
            o.hasHit = true
            onPlayerHit()
        }
    }

    private fun onPlayerHit() {
        lives -= 1
        invulnTimer = 1.2f
        audio.playHit()
        if (lives <= 0) {
            endGame()
        }
    }

    private fun endGame() {
        state = GameState.GAME_OVER
        audio.pauseMusic()
        newBestAchieved = score > bestScore
        if (newBestAchieved) {
            bestScore = score
            prefs.edit().putInt("best_score", bestScore).apply()
            audio.playHighscore()
        }
    }

    // ---------------------------------------------------------------
    // input
    // ---------------------------------------------------------------
    override fun onTouchEvent(event: MotionEvent): Boolean {
        if (event.action != MotionEvent.ACTION_DOWN) return true
        when (state) {
            GameState.MENU -> handleMenuTap(event.x, event.y)
            GameState.PLAYING -> handleJumpTap()
            GameState.GAME_OVER -> handleGameOverTap(event.x, event.y)
        }
        return true
    }

    private fun handleMenuTap(x: Float, y: Float) {
        for ((i, rect) in cards.withIndex()) {
            if (rect.contains(x, y)) {
                scenery = sceneryOrder[i]
                beginRun()
                return
            }
        }
    }

    private fun handleGameOverTap(x: Float, y: Float) {
        for ((i, rect) in cards.withIndex()) {
            if (rect.contains(x, y)) {
                scenery = sceneryOrder[i]
                beginRun()
                return
            }
        }
        // tap outside the scenery cards: just restart with the current scenery
        restartGame()
    }

    private fun handleJumpTap() {
        if (grounded) {
            velY = -jumpVelFrac * canvasH
            grounded = false
            audio.playJump()
        }
    }

    private fun beginRun() {
        lives = startingLives
        survivalTime = 0f
        score = 0
        newBestAchieved = false
        playerY = groundY - playerH
        velY = 0f
        grounded = true
        invulnTimer = 0f
        animFrame = 0
        spawnTimer = 1.0f
        flyingSpawnTimer = 3f + Math.random().toFloat() * 3f
        heartSpawnTimer = heartSpawnIntervalSeconds
        for (o in obstacles) o.active = false
        for (o in flyingObstacles) o.active = false
        for (h in heartPickups) h.active = false
        state = GameState.PLAYING
        audio.startMusic()
    }

    private fun restartGame() {
        beginRun()
    }

    // ---------------------------------------------------------------
    // draw
    // ---------------------------------------------------------------
    private fun renderFrame(canvas: Canvas) {
        if (canvasH <= 0) return
        when (state) {
            GameState.MENU -> drawMenu(canvas)
            GameState.PLAYING -> drawGame(canvas)
            GameState.GAME_OVER -> {
                drawGame(canvas)
                drawGameOverOverlay(canvas)
            }
        }
    }

    private fun drawScrollingBackground(canvas: Canvas) {
        val bmp = scaledBg.getValue(scenery)
        var x = -bgOffset
        if (x > 0f) x -= scaledBgWidth
        while (x < canvasW) {
            canvas.drawBitmap(bmp, x, 0f, null)
            x += scaledBgWidth
        }
    }

    private val obstacleBitmapCache = HashMap<Int, Bitmap>()
    private val obstacleSizeBucket = 6 // px — keeps the scaled-bitmap cache small over long sessions

    private fun getObstacleBitmap(scenery: Scenery, w: Int, h: Int): Bitmap {
        val bucketedH = (h / obstacleSizeBucket) * obstacleSizeBucket
        val bucketedW = (w / obstacleSizeBucket) * obstacleSizeBucket
        val key = scenery.ordinal * 100000 + bucketedH
        return obstacleBitmapCache.getOrPut(key) {
            Bitmap.createScaledBitmap(srcObstacle.getValue(scenery), bucketedW.coerceAtLeast(1), bucketedH.coerceAtLeast(1), true)
        }
    }

    private fun drawGame(canvas: Canvas) {
        drawScrollingBackground(canvas)

        for (o in obstacles) {
            if (!o.active) continue
            val bmp = getObstacleBitmap(scenery, o.width.toInt(), o.height.toInt())
            canvas.drawBitmap(bmp, o.x, groundY - o.height, null)
        }

        val flyFrames = scaledFly.getValue(scenery)
        for (o in flyingObstacles) {
            if (!o.active) continue
            val frameIdx = if ((o.bobPhase * 2f).toInt() % 2 == 0) 0 else 1
            canvas.drawBitmap(flyFrames[frameIdx], o.x, o.currentY(canvasH * flyBobAmplitudeFrac), null)
        }

        heartPickupScaled?.let { pickupBmp ->
            for (h in heartPickups) {
                if (!h.active) continue
                canvas.drawBitmap(pickupBmp, h.x, h.y, null)
            }
        }

        // player (flash while invulnerable by skipping draw on alternating frames)
        val showHitFrame = invulnTimer > 0f
        val blinkHidden = showHitFrame && ((invulnTimer * 10).toInt() % 2 == 0)
        if (!blinkHidden) {
            val frameBmp = when {
                showHitFrame -> playerFrames[4]
                !grounded -> playerFrames[3]
                animFrame == 2 -> playerFrames[2]
                animFrame == 1 -> playerFrames[1]
                else -> playerFrames[0]
            }
            canvas.drawBitmap(frameBmp, playerX, playerY, null)
        }

        // HUD: hearts top-left
        val heart = heartFullScaled
        val heartEmpty = heartEmptyScaled
        if (heart != null && heartEmpty != null) {
            val pad = canvasH * 0.03f
            for (i in 0 until maxLives) {
                val bmp = if (i < lives) heart else heartEmpty
                canvas.drawBitmap(bmp, pad + i * (heart.width + pad * 0.4f), pad, null)
            }
        }

        // HUD: score top-right
        canvas.drawText(score.toString(), canvasW - canvasH * 0.03f, canvasH * 0.12f, scorePaint)
    }

    private fun drawSceneryCards(canvas: Canvas) {
        for ((i, rect) in cards.withIndex()) {
            val sc = sceneryOrder[i]
            val bmp = scaledBg.getValue(sc)
            canvas.save()
            canvas.clipRect(rect)
            val scale = rect.height() / bmp.height
            val drawW = bmp.width * scale
            canvas.drawBitmap(bmp, null, RectF(rect.left, rect.top, rect.left + drawW, rect.bottom), null)
            if (drawW < rect.width()) {
                canvas.drawBitmap(bmp, null, RectF(rect.left + drawW, rect.top, rect.left + drawW * 2, rect.bottom), null)
            }
            canvas.restore()
            canvas.drawRect(rect, cardBgPaint)
            canvas.drawRect(rect, if (sc == scenery) cardSelectedBorderPaint else cardBorderPaint)
            canvas.drawText(sceneryLabel.getValue(sc), rect.centerX(), rect.bottom + canvasH * 0.07f, labelPaint)
        }
    }

    private fun drawMenu(canvas: Canvas) {
        // simple gradient-ish backdrop using the mountains bg as ambience
        drawScrollingBackground(canvas)
        canvas.drawRect(0f, 0f, canvasW.toFloat(), canvasH.toFloat(), overlayPaint)

        canvas.drawText("Wähle deine Welt", canvasW / 2f, canvasH * 0.10f, titlePaint)
        drawSceneryCards(canvas)

        if (bestScore > 0) {
            canvas.drawText("Bestleistung: $bestScore", canvasW / 2f, canvasH * 0.93f, labelPaint)
        }
    }

    private fun drawGameOverOverlay(canvas: Canvas) {
        canvas.drawRect(0f, 0f, canvasW.toFloat(), canvasH.toFloat(), overlayPaint)
        canvas.drawText(score.toString(), canvasW / 2f, canvasH * 0.10f, bigScorePaint)
        val sub = if (newBestAchieved) "Neuer Highscore!" else "Bestleistung: $bestScore"
        canvas.drawText(sub, canvasW / 2f, canvasH * 0.155f, labelPaint)
        drawSceneryCards(canvas)
        canvas.drawText("Szenerie wählen oder tippen zum Neustart", canvasW / 2f, canvasH * 0.93f, labelPaint)
    }
}
