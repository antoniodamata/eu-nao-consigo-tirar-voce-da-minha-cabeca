import SwiftUI

struct ContentView: View {

    @State private var motion = MotionManager()

    var body: some View {

        VStack(spacing: 24) {

            Text("iPhone Monitor")
                .font(.largeTitle)

            Divider()

            Text("Accelerometer")
                .font(.headline)

            Text("X: \(motion.state.accelerationX)")
            Text("Y: \(motion.state.accelerationY)")
            Text("Z: \(motion.state.accelerationZ)")

        }
        .padding()

    }

}

#Preview {
    ContentView()
}
