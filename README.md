# check_snmp_sfp
Icinga/Nagios Plugin to check SFP status of Switches/Router using SNMP

Currently this plugin only supports Juniper.

The current values are compared with Juniper preconfigured threshold values.

## Supported/Tested Models and Version

| Vendor       | Hardware Model | Software Version |
| ------------ | -------------- | ---------------- |
| Juniper      | ex4650-48y-8c  | 21.3R1.9         |

If you have been able to run this on other models please feel free to submit a PULL request or create an Issue.

## Example
### BIAS Current
```
./check_snmp_sfp.pl -H 10.0.0.1 -C abcdefgh -2 -n xe-0/0/0 -B
xe-0/0/0: 37.25 mA: OK
```

### Module Temperature
```
./check_snmp_sfp.pl -H 10.0.0.1 -C abcdefgh -2 -n xe-0/0/0 -T
xe-0/0/0: 30 degrees C: OK
```

### Laser TX/RX power
```
./check_snmp_sfp.pl -H 10.0.0.1 -C abcdefgh -2 -n xe-0/0/0 -L
xe-0/0/0: RX: -6.12 dBm TX: -2.64 dBm: OK
```

### Module Voltage
```
./check_snmp_sfp.pl -H 10.0.0.1 -C abcdefgh -2 -n xe-0/0/0 -V
xe-0/0/0: 3.356 V: OK
```

## TODO
  - Add multivendor support
