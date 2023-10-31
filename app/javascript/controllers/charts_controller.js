import {Controller} from "@hotwired/stimulus";
import ApexCharts from "apexcharts"
import humanizeDuration from "humanize-duration";

const formatTypes = ["number", "time"]
const chartTypes = ["area", "line", "stacked-bar"]
const chartColors = [
  "#1A56DB", "#9061F9", "#E74694", "#31C48D", "#FDBA8C", "#16BDCA",
  "#7E3BF2", "#1C64F2", "#F05252"
];

export default class extends Controller {
  static targets = ["chart"]

  static values = {
    type: String,
    format: {type: String, default: "number"},
    series: Array,
  }

  initialize() {
    const chartType = this.typeValue

    if (!chartTypes.includes(chartType)) {
      console.error('Invalid chart type.')
      return;
    }

    if (!formatTypes.includes(this.formatValue)) {
      console.error('Invalid data format type.')
      return;
    }

    let series = this.seriesValue
    let chartOptions

    if (chartType === "area") {
      chartOptions = this.areaOptions(series)
    } else if (chartType === "line") {
      chartOptions = this.lineOptions(series)
    } else if (chartType === "stacked-bar") {
      chartOptions = this.stackedBarOptions(series)
    }

    console.log(series);
    this.chart = new ApexCharts(this.chartTarget, chartOptions);
    this.chart.render();
  }

  areaOptions(series) {
    let self = this;

    return {
      chart: {
        height: "100%",
        maxWidth: "100%",
        width: "100%",
        type: "area",
        fontFamily: "Inter, sans-serif",
        dropShadow: {
          enabled: true,
          enabledSeries: [0],
          top: -2,
          left: 2,
          blur: 5,
          opacity: 0.1
        },
        toolbar: {
          show: false,
        },
      },
      tooltip: {
        enabled: true,
        x: {
          show: false,
        },
        y: {
          formatter(val) {
            if (self.__isTimeFormat()) {
              return self.__formatSeconds(val)
            } else {
              return val
            }
          },
        },
      },
      fill: {
        type: "gradient",
        gradient: {
          opacityFrom: 0.55,
          opacityTo: 0,
          shade: "#1C64F2",
          gradientToColors: ["#1C64F2"],
        },
      },
      dataLabels: {
        enabled: false,
      },
      stroke: {
        width: 6,
      },
      grid: {
        show: true,
        strokeDashArray: 4,
        padding: {
          left: -5,
          right: 5,
        },
      },
      series: series,
      xaxis: {
        tickPlacement: 'between',
        labels: {
          show: true,
        },
        tooltip: {
          enabled: false
        },
        axisBorder: {
          show: false,
        },
        axisTicks: {
          show: false,
        },
      },
      yaxis: {
        show: false,
      },
    }
  }

  lineOptions(series) {
    let self = this;

    return {
      chart: {
        height: "100%",
        maxWidth: "100%",
        type: "line",
        fontFamily: "Inter, sans-serif",
        dropShadow: {
          enabled: false,
        },
        toolbar: {
          show: false,
        },
      },
      tooltip: {
        enabled: true,
        x: {
          show: false,
        },
        y: {
          formatter(val) {
            if (self.__isTimeFormat()) {
              return self.__formatSeconds(val)
            } else {
              return val
            }
          },
        },
      },
      dataLabels: {
        enabled: false,
      },
      grid: {
        show: true,
        strokeDashArray: 4,
        padding: {
          left: 2,
          right: 2,
          top: -20
        },
      },
      series: series,
      legend: {
        show: false
      },
      stroke: {
        width: 3,
        curve: 'smooth'
      },
      xaxis: {
        tickPlacement: 'between',
        labels: {
          show: true,
          style: {
            fontFamily: "Inter, sans-serif",
            cssClass: 'text-xs font-normal fill-gray-500'
          },
          tooltip: {
            enabled: false
          },
        },
        axisBorder: {
          show: true,
        },
        axisTicks: {
          show: true,
        },
      },
      yaxis: {
        show: false,
      },
    }
  }

  stackedBarOptions(series) {
    let self = this;

    return {
      series: series,
      chart: {
        type: "bar",
        stacked: true,
        stackType: "100%",
        height: "200",
        fontFamily: "Inter, sans-serif",
        toolbar: {
          show: false,
        },
      },
      plotOptions: {
        bar: {
          horizontal: false,
          rangeBarGroupRows: true,
        },
      },
      tooltip: {
        style: {
          fontFamily: "Inter, sans-serif",
        },
        y: {
          formatter(val) {
            if (self.__isTimeFormat()) {
              return self.__formatSeconds(val)
            } else {
              return val
            }
          },
        },
      },
      states: {
        hover: {
          filter: {
            type: "darken",
            value: 1,
          },
        },
      },
      stroke: {
        show: true,
        width: 0,
        colors: ["transparent"],
      },
      grid: {
        show: true,
        strokeDashArray: 4,
        padding: {
          left: 2,
          right: 2,
          top: -14
        },
      },
      dataLabels: {
        enabled: true,
        style: {
          fontSize: '10px',
        },
        formatter(val) {
          if (self.__isTimeFormat()) {
            return self.__formatSeconds(val, true)
          } else {
            return val
          }
        },
      },
      legend: {
        show: false,
      },
      xaxis: {
        show: true,
        labels: {
          show: true,
          style: {
            fontFamily: "Inter, sans-serif",
            cssClass: 'text-xs font-normal fill-gray-500'
          }
        },
        axisBorder: {
          show: false,
        },
        axisTicks: {
          show: false,
        },
      },
      yaxis: {
        show: false,
      },
      fill: {
        opacity: 1,
      },
    }
  }

  // __pickColor(i) {
  //   const colorsLength = chartColors.length;
  //   const colorIndex = ((i % colorsLength) + colorsLength) % colorsLength;
  //   return chartColors[colorIndex];
  // }
  //
  // __validateData(names, series, categories) {
  //   if (names.length !== series.length) {
  //     console.error('Names and Series must have the same number of top-level items.');
  //     return false;
  //   }
  //
  //   if (categories.length > 0 && series.some(dataset => dataset.length !== categories.length)) {
  //     console.error('Categories and each dataset in the Series must be equal in size');
  //     return false;
  //   }
  //
  //   return true;
  // }
  //
  // __validateStackBarData(names, series, categories) {
  //   if (categories.length !== series.length) {
  //     console.error('Categories and Series must have the same number of top-level items.');
  //     return false;
  //   }
  //
  //   if (names.length > 0 && series.some(dataset => dataset.length !== names.length)) {
  //     console.error('Names and each dataset in the Series must be equal in size');
  //     return false;
  //   }
  //
  //   return true;
  // }

  __formatSeconds(seconds, isShort) {
    const ms = seconds * 1000
    if (isShort) {
      return humanizeDuration(ms, {
        round: true,
        largest: 1,
        maxDecimalPoints: 1,
        units: ["h", "m", "s"],
        language: "shortEn",
        languages: {shortEn: {h: () => "h", m: () => "m", s: () => "s"}}
      })
    } else {
      return humanizeDuration(ms, {round: true, largest: 2, maxDecimalPoints: 1})
    }
  }

  __isTimeFormat() {
    return this.formatValue === "time"
  }
}

