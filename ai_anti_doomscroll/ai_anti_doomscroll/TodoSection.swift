//
//  TodoSection.swift
//  ai_anti_doomscroll
//

import SwiftUI

struct TodoSection: View {
    var overallTodos: [Todo]
    var focusTodos: [Todo]
    @Binding var newTask: String
    var addTodo: () -> Void
    var deleteTodo: (Int) -> Void
    var moveToFocus: (Int) -> Void
    var moveToOverall: (Int) -> Void
    var completeTodo: (Int) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // ── Top Half: Today's Focus ──────────────────────────────
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Today's Focus")
                            .font(.title3).bold()
                        Text("AI will coach you on these tasks")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text("\(focusTodos.count)")
                        .font(.caption).bold()
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.15))
                        .foregroundColor(.green)
                        .clipShape(Capsule())
                }

                if focusTodos.isEmpty {
                    emptyState(icon: "target", message: "Tap \"Today\" on a task below to focus on it")
                } else {
                    VStack(spacing: 8) {
                        ForEach(focusTodos) { todo in
                            HStack(alignment: .top, spacing: 12) {
                                Circle()
                                    .stroke(Color.green, lineWidth: 2)
                                    .frame(width: 12, height: 12)
                                    .padding(.top, 4)

                                Text(todo.task)
                                    .font(.body)
                                    .fixedSize(horizontal: false, vertical: true)

                                Spacer()

                                // Complete button
                                Button(action: { completeTodo(todo.id) }) {
                                    HStack(spacing: 3) {
                                        Image(systemName: "checkmark.circle.fill")
                                        Text("Done")
                                    }
                                    .font(.caption2).bold()
                                    .foregroundColor(.green)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(Color.green.opacity(0.12))
                                    .cornerRadius(8)
                                }

                                Button(action: { deleteTodo(todo.id) }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.gray.opacity(0.4))
                                }
                            }
                            .padding(14)
                            .background(AppTheme.rowBackground)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.green.opacity(0.25), lineWidth: 1)
                            )
                        }
                    }
                }
            }
            .padding(16)
            .background(AppTheme.cardBackground)
            .cornerRadius(20)
            .shadow(color: AppTheme.cardShadowColor, radius: AppTheme.cardShadowRadius, x: 0, y: AppTheme.cardShadowY)

            // ── Divider ──────────────────────────────────────────────
            HStack(spacing: 8) {
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color(.systemGray4))
                Text("ALL TASKS")
                    .font(.caption2).bold()
                    .foregroundColor(.blue)
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color(.systemGray4))
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 4)

            // ── Bottom Half: All Tasks ───────────────────────────────
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("All Tasks")
                            .font(.title3).bold()
                        Text("Dump everything you need to do here")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text("\(overallTodos.count)")
                        .font(.caption).bold()
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .clipShape(Capsule())
                }

                // Task Input
                HStack(spacing: 12) {
                    TextField("Add a task…", text: $newTask)
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)

                    Button(action: addTodo) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                    .disabled(newTask.isEmpty)
                }

                if overallTodos.isEmpty {
                    emptyState(icon: "tray", message: "No tasks yet. Add one above!")
                } else {
                    VStack(spacing: 8) {
                        ForEach(overallTodos) { todo in
                            HStack(alignment: .top, spacing: 12) {
                                Circle()
                                    .stroke(Color.blue, lineWidth: 2)
                                    .frame(width: 12, height: 12)
                                    .padding(.top, 4)

                                Text(todo.task)
                                    .font(.body)
                                    .fixedSize(horizontal: false, vertical: true)

                                Spacer()

                                Button(action: { moveToFocus(todo.id) }) {
                                    HStack(spacing: 3) {
                                        Image(systemName: "arrow.up.circle.fill")
                                        Text("Today")
                                    }
                                    .font(.caption2).bold()
                                    .foregroundColor(.blue)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(AppTheme.primaryButton.opacity(0.1))
                                    .cornerRadius(8)
                                }

                                Button(action: { deleteTodo(todo.id) }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.gray.opacity(0.4))
                                }
                            }
                            .padding(14)
                            .background(AppTheme.rowBackground)
                            .cornerRadius(12)
                        }
                    }
                }
            }
            .padding(16)
            .background(AppTheme.cardBackground)
            .cornerRadius(20)
            .shadow(color: AppTheme.cardShadowColor, radius: AppTheme.cardShadowRadius, x: 0, y: AppTheme.cardShadowY)
        }
    }

    @ViewBuilder
    private func emptyState(icon: String, message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(.gray.opacity(0.5))
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(white: 0.80), style: StrokeStyle(lineWidth: 1, dash: [5]))
        )
    }
}
