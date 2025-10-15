using Plots


# define the sag curve function
function do_analytic(x, C0, B0, N0, ka, kc, kn, Cs, U)
    B = B0 * exp(-kc * x / U)
    N = N0 * exp(-kn * x / U)
    α1 = exp(-ka * x / U)
    α2 = (kc/(ka-kc)) * (exp(-kc * x / U) - exp(-ka * x / U))
    α3 = (kn/(ka-kn)) * (exp(-kn * x / U) - exp(-ka * x / U))
    C = Cs * (1 - α1) + (C0 * α1) - (B0 * α2) - (N0 * α3)
    return (C, B, N)
end


# river properties
U = 6.0        # velocity (km/day)
ka = 0.55      # reaeration rate
kc = 0.35      # CBOD decay
kn = 0.25      # NBOD decay
Cs = 10.0      # DO saturation


# Flows (m³/day)
Qr = 100000.0
Qw1 = 10000.0
Qw2 = 15000.0


# DO, CBOD, NBOD concentrations (mg/L)
DOr = 7.5;   Cw1 = 5.0;   Cw2 = 5.0
Br = 5.0;   Bw1 = 50.0;  Bw2 = 45.0
Nr = 5.0;   Nw1 = 35.0;  Nw2 = 35.0


# 1) MIX RIVER + WASTE 1 at x = 0
Q1 = Qr + Qw1
C01 = (Qr*DOr + Qw1*Cw1) / Q1
B01 = (Qr*Br + Qw1*Bw1) / Q1
N01 = (Qr*Nr + Qw1*Nw1) / Q1


# simulate from x = 0 to x = 15 km
x1 = 0:0.1:15
results1 = [(x, do_analytic(x, C01, B01, N01, ka, kc, kn, Cs, U)) for x in x1]


# get concentrations at x = 15 km (last point of previous)
C15, B15, N15 = results1[end][2]


# 2) MIX with WASTE 2 at x = 15 km
Q2 = Q1 + Qw2
C02 = (Q1*C15 + Qw2*Cw2) / Q2
B02 = (Q1*B15 + Qw2*Bw2) / Q2
N02 = (Q1*N15 + Qw2*Nw2) / Q2


# simulate from x = 0 (meaning relative to second discharge) to 35 km (total 50 km)
x2 = 0.1:0.1:35  # skip 0 to avoid duplicate point
results2 = [(x + 15, do_analytic(x, C02, B02, N02, ka, kc, kn, Cs, U)) for x in x2]


# combine results
x_all = [r[1] for r in results1] ∪ [r[1] for r in results2]
C_all = [r[2][1] for r in results1] ∪ [r[2][1] for r in results2]
B_all = [r[2][2] for r in results1] ∪ [r[2][2] for r in results2]
N_all = [r[2][3] for r in results1] ∪ [r[2][3] for r in results2]


# find minimum DO and where it occurs
C_min = minimum(C_all)
idx_min = argmin(C_all)
x_min = x_all[idx_min]


println("Minimum DO: $(round(C_min, digits=2)) mg/L at $(round(x_min, digits=2)) km")


# plot
p = plot(; xlabel="Distance (km)", ylabel="Concentration (mg/L)", legend=:bottomright)
plot!(p, x_all, C_all, label="DO", color=:black, linewidth=3)
plot!(p, x_all, B_all, label="CBOD", color=:green, linestyle=:dash)
plot!(p, x_all, N_all, label="NBOD", color=:blue, linestyle=:dot)
plot!(p, x_all, fill(Cs, length(x_all)), label="DO Saturation", color=:purple, linestyle=:dashdot)
hline!([3], color=:red, label="Regulatory Limit", linewidth=2)
scatter!([x_min], [C_min], label="Minimum DO", color=:red, markersize=6)
