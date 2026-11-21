import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: HikmaStore
    @Environment(\.dismiss) private var dismiss
    @State private var newStartHour = 8
    @State private var confirmsRestart = false
    @State private var sentTest = false

    var body: some View {
        NavigationStack {
            Form {
                if !store.notificationsAllowed {
                    Section {
                        Text("الإشعارات متوقفة، فلن تصلك الحكم.")
                        Button("افتح إعدادات الإشعارات") { store.openSystemSettings() }
                    }
                }

                Section {
                    Toggle("حكمة كل أربع ساعات", isOn: Binding(
                        get: { store.sayingsEnabled },
                        set: { value in Task { await store.setSayingsEnabled(value) } }))
                } footer: {
                    Text("أوقفها إن أردت أن تصلك بطاقات الكتاب وحدها.")
                }

                Section {
                    SchedulePicker(startHour: $newStartHour)
                        .listRowBackground(Color.clear)
                    if newStartHour % 4 != store.startHour % 4 {
                        Button("اعتمد المواعيد الجديدة") { confirmsRestart = true }
                    }
                } footer: {
                    Text("تغيير المواعيد يبدأ دورةً جديدة من أربعة عشر يومًا.")
                }

                Section {
                    Button(sentTest ? "ستصلك بعد خمس ثوانٍ…" : "أرسل حكمة تجريبية") {
                        sentTest = true
                        Task { await store.sendTest() }
                    }
                    .disabled(sentTest)
                    if store.activeBook != nil {
                        Button("أرسل بطاقة كتاب تجريبية") {
                            Task { await store.sendBookTest() }
                        }
                    }
                    Button("ابدأ دورة جديدة الآن") {
                        newStartHour = store.startHour
                        confirmsRestart = true
                    }
                }

                Section {
                    LabeledContent("المكتبة", value: "\(Arabic.number(QuoteLibrary.all.count)) حكمة")
                    LabeledContent("الثقافات", value: Arabic.number(QuoteLibrary.cultureCount))
                    if let cycle = store.cycle {
                        LabeledContent("نهاية الدورة", value: Arabic.dayAndTime(cycle.date(ofSlot: Cycle.totalSlots - 1)))
                    }
                } footer: {
                    Text("افتح التطبيق مرةً كل بضعة أيام ليجهّز بقية الحكم؛ فنظام iOS لا يحتفظ إلا بعددٍ محدود من الإشعارات المجدولة. وإن نسيت، سيذكّرك إشعار.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.paper)
            .navigationTitle("الإعدادات")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("تم") { dismiss() }
                }
            }
            .confirmationDialog("بدء دورة جديدة؟", isPresented: $confirmsRestart, titleVisibility: .visible) {
                Button("ابدأ دورة جديدة") {
                    Task {
                        await store.begin(startHour: newStartHour)
                        dismiss()
                    }
                }
                Button("إلغاء", role: .cancel) {}
            } message: {
                Text("ستبدأ أربعة عشر يومًا جديدة بحكم مختارة من جديد.")
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .tint(Theme.ink)
        .onAppear { newStartHour = store.startHour }
    }
}
