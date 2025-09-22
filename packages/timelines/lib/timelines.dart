library timelines;

import 'package:flutter/material.dart';

class TimelineTheme extends InheritedWidget {
  const TimelineTheme({super.key, required this.data, required super.child});

  final TimelineThemeData data;

  static TimelineThemeData of(BuildContext context) {
    final theme = context.dependOnInheritedWidgetOfExactType<TimelineTheme>();
    return theme?.data ?? const TimelineThemeData();
  }

  @override
  bool updateShouldNotify(TimelineTheme oldWidget) => data != oldWidget.data;
}

class TimelineThemeData {
  const TimelineThemeData({
    this.nodePosition = 0.0,
    this.connectorTheme = const ConnectorThemeData(),
    this.indicatorTheme = const IndicatorThemeData(),
  });

  final double nodePosition;
  final ConnectorThemeData connectorTheme;
  final IndicatorThemeData indicatorTheme;

  TimelineThemeData copyWith({
    double? nodePosition,
    ConnectorThemeData? connectorTheme,
    IndicatorThemeData? indicatorTheme,
  }) {
    return TimelineThemeData(
      nodePosition: nodePosition ?? this.nodePosition,
      connectorTheme: connectorTheme ?? this.connectorTheme,
      indicatorTheme: indicatorTheme ?? this.indicatorTheme,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TimelineThemeData &&
        other.nodePosition == nodePosition &&
        other.connectorTheme == connectorTheme &&
        other.indicatorTheme == indicatorTheme;
  }

  @override
  int get hashCode => Object.hash(nodePosition, connectorTheme, indicatorTheme);
}

class ConnectorThemeData {
  const ConnectorThemeData({
    this.color,
    this.thickness = 2.0,
  });

  final Color? color;
  final double thickness;

  ConnectorThemeData copyWith({Color? color, double? thickness}) {
    return ConnectorThemeData(
      color: color ?? this.color,
      thickness: thickness ?? this.thickness,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ConnectorThemeData &&
        other.color == color &&
        other.thickness == thickness;
  }

  @override
  int get hashCode => Object.hash(color, thickness);
}

class IndicatorThemeData {
  const IndicatorThemeData({
    this.color,
    this.size,
  });

  final Color? color;
  final double? size;

  IndicatorThemeData copyWith({Color? color, double? size}) {
    return IndicatorThemeData(
      color: color ?? this.color,
      size: size ?? this.size,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is IndicatorThemeData &&
        other.color == color &&
        other.size == size;
  }

  @override
  int get hashCode => Object.hash(color, size);
}

enum ConnectionDirection { before, after }

enum ConnectorType { start, end }

abstract class TimelineTileBuilder {
  const TimelineTileBuilder();

  Widget build(BuildContext context, TimelineThemeData theme);

  factory TimelineTileBuilder.connected({
    required ConnectionDirection connectionDirection,
    required int itemCount,
    required Widget? Function(BuildContext, int) contentsBuilder,
    required Widget Function(BuildContext, int) indicatorBuilder,
    required Widget Function(BuildContext, int, ConnectorType) connectorBuilder,
  }) => _ConnectedTimelineBuilder(
        connectionDirection: connectionDirection,
        itemCount: itemCount,
        contentsBuilder: contentsBuilder,
        indicatorBuilder: indicatorBuilder,
        connectorBuilder: connectorBuilder,
      );
}

class _ConnectedTimelineBuilder extends TimelineTileBuilder {
  const _ConnectedTimelineBuilder({
    required this.connectionDirection,
    required this.itemCount,
    required this.contentsBuilder,
    required this.indicatorBuilder,
    required this.connectorBuilder,
  });

  final ConnectionDirection connectionDirection;
  final int itemCount;
  final Widget? Function(BuildContext, int) contentsBuilder;
  final Widget Function(BuildContext, int) indicatorBuilder;
  final Widget Function(BuildContext, int, ConnectorType) connectorBuilder;

  @override
  Widget build(BuildContext context, TimelineThemeData theme) {
    final children = <Widget>[];
    for (var i = 0; i < itemCount; i++) {
      final content = contentsBuilder(context, i);
      final indicator = indicatorBuilder(context, i);
      final startConnector = connectorBuilder(context, i, ConnectorType.start);
      final endConnector = connectorBuilder(context, i, ConnectorType.end);
      children.add(_TimelineTile(
        content: content,
        indicator: indicator,
        startConnector: i == 0 && connectionDirection == ConnectionDirection.before
            ? const SizedBox.shrink()
            : startConnector,
        endConnector: i == itemCount - 1 &&
                connectionDirection == ConnectionDirection.before
            ? const SizedBox.shrink()
            : endConnector,
        theme: theme,
      ));
    }
    return Column(children: children);
  }
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({
    required this.content,
    required this.indicator,
    required this.startConnector,
    required this.endConnector,
    required this.theme,
  });

  final Widget? content;
  final Widget indicator;
  final Widget startConnector;
  final Widget endConnector;
  final TimelineThemeData theme;

  @override
  Widget build(BuildContext context) {
    final connectors = Column(
      children: [
        Expanded(child: Align(alignment: Alignment.topCenter, child: startConnector)),
        indicator,
        Expanded(child: Align(alignment: Alignment.bottomCenter, child: endConnector)),
      ],
    );

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 40,
            child: Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(width: 16, child: connectors),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: content ?? const SizedBox.shrink()),
        ],
      ),
    );
  }
}

class FixedTimeline extends StatelessWidget {
  const FixedTimeline.tileBuilder({super.key, required this.theme, required this.builder});

  final TimelineThemeData theme;
  final TimelineTileBuilder builder;

  @override
  Widget build(BuildContext context) {
    return TimelineTheme(
      data: theme,
      child: builder.build(context, theme),
    );
  }
}

class DotIndicator extends StatelessWidget {
  const DotIndicator({super.key, this.size, this.color});

  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = TimelineTheme.of(context);
    final resolvedSize = size ?? theme.indicatorTheme.size ?? 16.0;
    final resolvedColor = color ?? theme.indicatorTheme.color ?? Colors.blue;
    return Container(
      width: resolvedSize,
      height: resolvedSize,
      decoration: BoxDecoration(
        color: resolvedColor,
        shape: BoxShape.circle,
      ),
    );
  }
}

class SolidLineConnector extends StatelessWidget {
  const SolidLineConnector({super.key, this.color, this.thickness});

  final Color? color;
  final double? thickness;

  @override
  Widget build(BuildContext context) {
    final theme = TimelineTheme.of(context);
    final resolvedColor = color ?? theme.connectorTheme.color ?? Colors.grey;
    final resolvedThickness = thickness ?? theme.connectorTheme.thickness;
    return Container(
      width: resolvedThickness,
      decoration: BoxDecoration(
        color: resolvedColor,
        borderRadius: BorderRadius.circular(resolvedThickness / 2),
      ),
    );
  }
}
