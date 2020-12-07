import 'package:flutter/material.dart';
import 'package:flutter_voice/palette.dart';

class SwitchItem extends StatelessWidget {
  final String label;
  final bool value;
  final bool disabled;
  final bool isLoading;
  final bool noTouch;
  final Function(bool value) onChange;

  const SwitchItem(
      {Key key, this.label = "", this.value = false, this.onChange, this.disabled = false, this.isLoading=false, this.noTouch =false,})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      absorbing: disabled || noTouch,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            onChange(!value);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                        fontSize: 18.0,
                        color: disabled ? Palette.colorLightGray : Palette.colorWhite,
                        fontWeight: FontWeight.w500),
                  ),
                ),
                isLoading?Theme(
                    data: Theme.of(context).copyWith(accentColor: Palette.colorPrimary),
                    child: CircularProgressIndicator()):SizedBox(),
                Switch(value: value,
                    inactiveThumbColor: disabled ? Palette.colorGray : Palette
                        .colorWhite,
                    activeColor: disabled ? Palette.colorGray : Palette
                        .colorPrimary,
                    onChanged: onChange)
              ],
            ),
          ),
        ),
      ),
    );
  }
}
