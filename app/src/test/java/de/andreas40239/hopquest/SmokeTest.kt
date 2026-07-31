package de.andreas40239.hopquest

import android.os.SystemClock
import android.view.MotionEvent
import android.view.ViewGroup
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [30])
class SmokeTest {

    @Test
    fun activityLaunchesWithoutCrashing() {
        val controller = Robolectric.buildActivity(MainActivity::class.java)
        controller.create().start().resume()

        val activity = controller.get()
        val contentRoot = activity.findViewById<ViewGroup>(android.R.id.content)
        val view = contentRoot.getChildAt(0) as GameView

        val w = 2400
        val h = 1080
        view.measure(
            android.view.View.MeasureSpec.makeMeasureSpec(w, android.view.View.MeasureSpec.EXACTLY),
            android.view.View.MeasureSpec.makeMeasureSpec(h, android.view.View.MeasureSpec.EXACTLY)
        )
        view.layout(0, 0, w, h)

        Thread.sleep(300) // let the menu render a few frames

        // tap the first scenery card (matches GameView's layoutMenuCards formula) to start playing
        val margin = w * 0.04f
        val gap = w * 0.03f
        val cardW = (w - margin * 2 - gap * 2) / 3f
        val cardTop = h * 0.20f
        val cardH = h * 0.56f
        val tapX = margin + cardW / 2f
        val tapY = cardTop + cardH / 2f

        dispatchTap(view, tapX, tapY)

        // run long enough (>10s) to exercise obstacle spawns, flying obstacles, pits and the heart pickup
        Thread.sleep(11_000)

        // tap again — now in PLAYING state this should just jump, not crash
        dispatchTap(view, tapX, tapY)
        Thread.sleep(300)

        // run past the 100s level boundary to trigger the boss fight
        Thread.sleep(92_000)

        // keep tapping (jump attempts) through ~20s of boss activity: whether balls are
        // dodged (advancing to the next level) or hit (possibly ending the run), both
        // paths must run cleanly
        repeat(14) {
            dispatchTap(view, tapX, tapY)
            Thread.sleep(1_400)
        }

        controller.pause().stop().destroy()
    }

    /**
     * Reproduces a tablet-specific crash: surfaceChanged (e.g. from split-screen /
     * free-form window resizing, more common on tablets) firing repeatedly on the UI
     * thread while the game thread is concurrently running update()/renderFrame().
     * Both now synchronize on the same monitor — this hammers that race directly.
     */
    @Test
    fun concurrentSurfaceResizeDuringGameplayDoesNotCrash() {
        val controller = Robolectric.buildActivity(MainActivity::class.java)
        controller.create().start().resume()

        val activity = controller.get()
        val contentRoot = activity.findViewById<ViewGroup>(android.R.id.content)
        val view = contentRoot.getChildAt(0) as GameView

        val w = 2560
        val h = 1600 // tablet-like, lower aspect ratio than a phone
        view.measure(
            android.view.View.MeasureSpec.makeMeasureSpec(w, android.view.View.MeasureSpec.EXACTLY),
            android.view.View.MeasureSpec.makeMeasureSpec(h, android.view.View.MeasureSpec.EXACTLY)
        )
        view.layout(0, 0, w, h)
        Thread.sleep(200)

        val margin = w * 0.04f
        val gap = w * 0.03f
        val cardW = (w - margin * 2 - gap * 2) / 3f
        val cardTop = h * 0.20f
        val cardH = h * 0.56f
        dispatchTap(view, margin + cardW / 2f, cardTop + cardH / 2f)

        var resizerFailed: Throwable? = null
        val resizer = Thread {
            try {
                val sizes = listOf(w to h, (w - 400) to (h - 200), w to h, (w + 200) to h, w to h)
                repeat(40) { i ->
                    val (rw, rh) = sizes[i % sizes.size]
                    view.surfaceChanged(view.holder, 0, rw, rh)
                }
            } catch (t: Throwable) {
                resizerFailed = t
            }
        }
        resizer.start()
        Thread.sleep(6_000) // game thread runs update()/renderFrame() concurrently the whole time
        resizer.join()

        resizerFailed?.let { throw AssertionError("surfaceChanged race crashed", it) }

        controller.pause().stop().destroy()
    }

    private fun dispatchTap(view: GameView, x: Float, y: Float) {
        val downTime = SystemClock.uptimeMillis()
        val down = MotionEvent.obtain(downTime, downTime, MotionEvent.ACTION_DOWN, x, y, 0)
        view.onTouchEvent(down)
        down.recycle()
        val up = MotionEvent.obtain(downTime, downTime + 50, MotionEvent.ACTION_UP, x, y, 0)
        view.onTouchEvent(up)
        up.recycle()
    }
}
