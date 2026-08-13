import WidgetKit
import SwiftUI

// Bundle del widget de Andén. Widget de próximo tren + Live Activity del tren seguido.
@main
struct AndenWidgetBundle: WidgetBundle {
    var body: some Widget {
        NextTrainWidget()
        TrainLiveActivity()
    }
}
