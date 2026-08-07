import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nomoride/features/registration/presentation/bloc/waitlist_cubit.dart';

extension WaitlistRefreshContext on BuildContext {
  Future<void> refreshWaitlistStatus() {
    return read<WaitlistCubit>().refresh();
  }
}
