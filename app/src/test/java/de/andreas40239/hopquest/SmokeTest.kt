package de.andreas40239.hopquest

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
        val view = activity.window.decorView
        // force a layout pass so surfaceChanged() / draw logic actually runs
        view.measure(
            android.view.View.MeasureSpec.makeMeasureSpec(1080, android.view.View.MeasureSpec.EXACTLY),
            android.view.View.MeasureSpec.makeMeasureSpec(2400, android.view.View.MeasureSpec.EXACTLY)
        )
        view.layout(0, 0, 1080, 2400)

        Thread.sleep(500) // let the game thread run a few frames

        controller.pause().stop().destroy()
    }
}
