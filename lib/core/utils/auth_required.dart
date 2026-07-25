import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:shop/providers/auth_provider.dart';
import 'package:shop/route/route_constants.dart';

bool requireAuthenticatedUser(
  BuildContext context, {
  String message = 'Please log in to continue.',
}) {
  if (context.read<AuthProvider>().isAuthenticated) {
    return true;
  }

  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  Navigator.pushNamed(context, logInScreenRoute);
  return false;
}
