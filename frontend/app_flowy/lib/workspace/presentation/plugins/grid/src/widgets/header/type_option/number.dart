import 'package:app_flowy/startup/startup.dart';
import 'package:app_flowy/workspace/application/grid/field/type_option/number_bloc.dart';
import 'package:app_flowy/workspace/presentation/plugins/grid/src/widgets/header/field_tyep_switcher.dart';
import 'package:flowy_infra/image.dart';
import 'package:flowy_infra/theme.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flowy_infra_ui/style_widget/button.dart';
import 'package:flowy_infra_ui/style_widget/text.dart';
import 'package:flowy_infra_ui/widget/spacing.dart';
import 'package:flowy_sdk/protobuf/flowy-grid/number_type_option.pb.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:easy_localization/easy_localization.dart' hide NumberFormat;
import 'package:app_flowy/generated/locale_keys.g.dart';

class NumberTypeOptionBuilder extends TypeOptionBuilder {
  NumberTypeOption typeOption;
  TypeOptionDataCallback typeOptionDataCallback;

  NumberTypeOptionBuilder(
    TypeOptionData typeOptionData,
    this.typeOptionDataCallback,
  ) : typeOption = NumberTypeOption.fromBuffer(typeOptionData);

  @override
  Widget? get customWidget => NumberTypeOptionWidget(
        typeOption: typeOption,
        updateCallback: typeOptionDataCallback,
      );
}

class NumberTypeOptionWidget extends TypeOptionWidget {
  final TypeOptionDataCallback updateCallback;
  final NumberTypeOption typeOption;
  const NumberTypeOptionWidget({required this.typeOption, required this.updateCallback, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppTheme>();
    return BlocProvider(
      create: (context) => getIt<NumberTypeOptionBloc>(param1: typeOption),
      child: SizedBox(
        height: 36,
        child: BlocConsumer<NumberTypeOptionBloc, NumberTypeOptionState>(
          listener: (context, state) => updateCallback(state.typeOption.writeToBuffer()),
          builder: (context, state) {
            return FlowyButton(
              text: FlowyText.medium(LocaleKeys.grid_field_numberFormat.tr(), fontSize: 12),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              hoverColor: theme.hover,
              onTap: () {
                NumberFormatList.show(context, (format) {
                  context.read<NumberTypeOptionBloc>().add(NumberTypeOptionEvent.didSelectFormat(format));
                });
              },
              rightIcon: svg("grid/more", color: theme.iconColor),
            );
          },
        ),
      ),
    );
  }
}

typedef _SelectNumberFormatCallback = Function(NumberFormat format);

class NumberFormatList extends StatelessWidget {
  final _SelectNumberFormatCallback onSelected;
  const NumberFormatList({required this.onSelected, Key? key}) : super(key: key);

  static void show(BuildContext context, _SelectNumberFormatCallback onSelected) {
    final list = NumberFormatList(onSelected: onSelected);
    FlowyOverlay.of(context).insertWithAnchor(
      widget: OverlayContainer(
        child: list,
        constraints: BoxConstraints.loose(const Size(140, 300)),
      ),
      identifier: list.identifier(),
      anchorContext: context,
      anchorDirection: AnchorDirection.leftWithCenterAligned,
      style: FlowyOverlayStyle(blur: false),
      anchorOffset: const Offset(-20, 0),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formatItems = NumberFormat.values.map((format) {
      return NumberFormatItem(
          format: format,
          onSelected: (format) {
            onSelected(format);
            FlowyOverlay.of(context).remove(identifier());
          });
    }).toList();

    return ListView.separated(
      shrinkWrap: true,
      controller: ScrollController(),
      separatorBuilder: (context, index) {
        return const VSpace(10);
      },
      itemCount: formatItems.length,
      itemBuilder: (BuildContext context, int index) {
        return formatItems[index];
      },
    );
  }

  String identifier() {
    return toString();
  }
}

class NumberFormatItem extends StatelessWidget {
  final NumberFormat format;
  final Function(NumberFormat format) onSelected;
  const NumberFormatItem({required this.format, required this.onSelected, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppTheme>();
    return SizedBox(
      height: 26,
      child: FlowyButton(
        text: FlowyText.medium(format.title(), fontSize: 12),
        hoverColor: theme.hover,
        onTap: () => onSelected(format),
        leftIcon: svg(format.iconName(), color: theme.iconColor),
      ),
    );
  }
}

extension NumberFormatExtension on NumberFormat {
  String title() {
    switch (this) {
      case NumberFormat.CNY:
        return "Yen";
      case NumberFormat.EUR:
        return "Euro";
      case NumberFormat.Number:
        return "Numbers";
      case NumberFormat.USD:
        return "US Dollar";
      default:
        throw UnimplementedError;
    }
  }

  String iconName() {
    switch (this) {
      case NumberFormat.CNY:
        return "grid/field/yen";
      case NumberFormat.EUR:
        return "grid/field/euro";
      case NumberFormat.Number:
        return "grid/field/numbers";
      case NumberFormat.USD:
        return "grid/field/us_dollar";
      default:
        throw UnimplementedError;
    }
  }
}