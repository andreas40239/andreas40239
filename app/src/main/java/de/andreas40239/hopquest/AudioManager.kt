package de.andreas40239.hopquest

import android.content.Context
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.SoundPool

/** Wraps SoundPool (short low-latency sfx) and a looping MediaPlayer (music). */
class GameAudio(context: Context) {

    private val appContext = context.applicationContext

    private val attrs = AudioAttributes.Builder()
        .setUsage(AudioAttributes.USAGE_GAME)
        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
        .build()

    private val soundPool = SoundPool.Builder()
        .setMaxStreams(4)
        .setAudioAttributes(attrs)
        .build()

    private var jumpId = 0
    private var hitId = 0
    private var highscoreId = 0
    private var loaded = false

    private var music: MediaPlayer? = null

    init {
        jumpId = soundPool.load(appContext, R.raw.sfx_jump, 1)
        hitId = soundPool.load(appContext, R.raw.sfx_hit, 1)
        highscoreId = soundPool.load(appContext, R.raw.sfx_highscore, 1)
        soundPool.setOnLoadCompleteListener { _, _, _ -> loaded = true }
    }

    fun playJump() {
        if (jumpId != 0) soundPool.play(jumpId, 0.8f, 0.8f, 1, 0, 1f)
    }

    fun playHit() {
        if (hitId != 0) soundPool.play(hitId, 1f, 1f, 2, 0, 1f)
    }

    fun playHighscore() {
        if (highscoreId != 0) soundPool.play(highscoreId, 0.9f, 0.9f, 2, 0, 1f)
    }

    fun startMusic() {
        if (music == null) {
            music = MediaPlayer.create(appContext, R.raw.bg_music)?.apply {
                isLooping = true
                setVolume(0.55f, 0.55f)
            }
        }
        music?.let { if (!it.isPlaying) it.start() }
    }

    fun pauseMusic() {
        music?.let { if (it.isPlaying) it.pause() }
    }

    fun resumeMusic() {
        music?.let { if (!it.isPlaying) it.start() }
    }

    fun release() {
        soundPool.release()
        music?.release()
        music = null
    }
}
