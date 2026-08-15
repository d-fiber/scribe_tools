// Copyright (C) 2026 Fiber
//
// All rights reserved. This script, including its code and logic, is the
// exclusive property of Fiber. Redistribution, reproduction,
// or modification of any part of this script is strictly prohibited
// without prior written permission from Fiber.
//
// Conditions of use:
// - The code may not be copied, duplicated, or used, in whole or in part,
//   for any purpose without explicit authorization.
// - Redistribution of this code, with or without modification, is not
//   permitted unless expressly agreed upon by Fiber.
// - The name "Fiber" and any associated branding, logos, or
//   trademarks may not be used to endorse or promote derived products
//   or services without prior written approval.
//
// Disclaimer:
// THIS SCRIPT AND ITS CODE ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE, OR NON-INFRINGEMENT. IN NO EVENT SHALL
// FIBER BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
// EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING BUT NOT LIMITED TO LOSS OF USE,
// DATA, PROFITS, OR BUSINESS INTERRUPTION) ARISING OUT OF OR RELATED TO THE USE
// OR INABILITY TO USE THIS SCRIPT, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
// Unauthorized copying or reproduction of this script, in whole or in part,
// is a violation of applicable intellectual property laws and will result
// in legal action.

enum ConnectionState { none, waiting, active, done }

class AsyncSnapshot<T> {
  const AsyncSnapshot({required this.connection, this.data, this.error, this.stack});

  const AsyncSnapshot.nothing() : connection = ConnectionState.none, data = null, error = null, stack = null;

  const AsyncSnapshot.waiting() : connection = ConnectionState.waiting, data = null, error = null, stack = null;

  const AsyncSnapshot.value(this.data, {this.connection = ConnectionState.done}) : error = null, stack = null;

  const AsyncSnapshot.failed(this.error, this.stack, {this.connection = ConnectionState.done}) : data = null;

  final ConnectionState connection;
  final T? data;
  final Object? error;
  final StackTrace? stack;

  bool get hasData => data != null;

  bool get hasError => error != null;

  bool get isWaiting => connection == ConnectionState.waiting;

  bool get isDone => connection == ConnectionState.done;
}
