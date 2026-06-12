# C-HVGSA: Constrained Hypervolume-based Gradient Subspace Approximation

Source code for the paper:

> Kenneth M. Zhang et al., **"Rapidly Handling Constrained Multi-objective Optimization Problems with Hypervolume Gradient Subspace Approximation,"** *IEEE Transactions on Evolutionary Computation*, accepted, 2026.
<!-- TODO: add DOI and final author list when available -->

HVGSA is a gradient-free local search for (constrained) multi-objective optimization. It approximates the hypervolume gradient in a subspace spanned by neighboring solutions and steps along it, requiring only function evaluations — no analytical gradients. The method plugs into any $(\mu+\mu)$ MOEA; this repository provides integrations with NSGA-II (the primary algorithm, **NSGA-II-HVGSA**), ICMA, and CMOEA-CD.

An earlier, unconstrained version of HVGSA was published at PPSN 2024:

> K. Zhang, A. E. Rodriguez-Fernandez, K. Shang, H. Ishibuchi, and O. Schütze, "Hypervolume Gradient Subspace Approximation," *Parallel Problem Solving from Nature — PPSN XVIII*, Springer, 2024, pp. 20–35. [doi:10.1007/978-3-031-70085-9_2](https://doi.org/10.1007/978-3-031-70085-9_2)

## Repository Organization

The repository is a trimmed distribution of [PlatEMO](https://github.com/BIMK/PlatEMO) v4.8 (MATLAB) with the HVGSA algorithms, benchmark pipelines, and figure scripts added.

```
PlatEMO/
├── platemo.m                          # PlatEMO entry point (GUI or command line)
├── Algorithms/
│   └── Multi-objective optimization/
│       ├── NSGA-II/
│       │   └── ConfigurableNSGA2CHVGSA/   # ★ NSGA-II-HVGSA (primary algorithm)
│       ├── ICMA/                      # ICMA baseline + ICMACHVGSA (ICMA-HVGSA)
│       ├── CMOEA-CD/                  # CMOEA-CD baseline + CMOEACDCHVGSA
│       ├── ConfigurableHVGSA/         # Standalone HVGSA (local search only)
│       ├── ConfigurableHVGA/          # Standalone HV gradient ascent (comparison)
│       ├── NSGA-III/, PPS/, ToP/      # Baselines used in the experiments
│       └── LocalSearchOnly/           # Algorithms for the illustrative examples
├── Benchmarks/                        # ★ Experiment pipelines (see "Reproducing...")
│   ├── BenchmarkPipeline.m            # Main RCM (RWMOP1–50) benchmark + ablations
│   ├── DASCMaOPPipeline.m             # Scalability study on DAS-CMaOP1
│   ├── RWMOPSensitivityAnalysis.m     # Parameter sensitivity analysis
│   └── PipelineFunctions/             # Metrics, statistics, plotting helpers
├── Problems/                          # PlatEMO problem suites (incl. RWMOPs = RCM)
├── Metrics/                           # HV, IGD, GD, Spread, Spacing
├── Global utilities/                  # Shared HVGSA components (GSA, step size,
│                                      #   hypervolume via STK/WFG, team selection, ...)
├── Info/ReferencePF/                  # Estimated reference Pareto fronts (RCM suite)
├── ProduceImage/                      # Scripts that generate the paper's figures
├── Visualization/                     # Additional visualization scripts
└── GUI/                               # PlatEMO graphical interface
```

## Requirements

- MATLAB (R2020b or newer recommended; required by PlatEMO v4.8's GUI).
- No extra toolboxes are needed for the core algorithms. Hypervolume computation uses the WFG algorithm from the [STK toolbox](https://stk-kriging.github.io/); the required `stk_*.m` files and compiled MEX binaries (`.mexw64` for Windows, `.mexa64` for Linux) are bundled in `PlatEMO/Global utilities/Hypervolume/`.

## Quick Start

All commands are run from the `PlatEMO/` directory.

### GUI

```matlab
platemo()   % NSGA-II-HVGSA appears as "ConfigurableNSGA2CHVGSA" in the algorithm list
```

### NSGA-II-HVGSA from the command line

```matlab
addpath(genpath('.'));

% Default configuration (as used in the paper)
algorithm = generateCHVGSA();

% Run on a constrained real-world problem (RCM suite)
platemo('algorithm', algorithm, 'problem', @RWMOP2, 'N', 120, 'maxFE', 30000);
```

`generateCHVGSA(...)` accepts name–value pairs and returns `{@ConfigurableNSGA2CHVGSA, config}`. The main options (defaults in bold):

| Option | Values | Meaning |
|---|---|---|
| `eta_mode` | **`'adaptive'`**, `'constant_one'`, `'constant_sqrtD'`, `'constant_invSqrtD'` | Step-size schedule (interpolative search η₀: √n → 1/√n) |
| `gradient_method` | **`'CGSA_n'`**, `'CGSA'` | Solution-wise vs. full normalization of the gradient subspace |
| `U_mode` / `U_range` / `U_value` | **`'random'`, `[6 10]`** / `'fixed'`, k | Search-team size U per generation |
| `sr_mode` / `k_min` | **`'mean'`**, `'min'`, `'max'` / **1** | Search-radius strategy and minimum neighbor count |
| `refC` | **`'adaptive'`** (1+1/H) or numeric (e.g. `1.1`) | Hypervolume reference-point constant |
| `Qsize` | **50**, `0` disables | Archive size for neighbor reuse |
| `use_expanded_front` | **`true`** | Use the expanded non-dominated front |
| `use_interpolation` | **`true`** | Interpolative step-size search |

Examples of the paper's ablation variants:

```matlab
generateCHVGSA('use_expanded_front', false)        % without expanded front
generateCHVGSA('use_interpolation', false)         % without interpolative search
generateCHVGSA('Qsize', 0)                         % without archive
generateCHVGSA('U_mode', 'fixed', 'U_value', 5)    % fixed team size U = 5
```

### HVGSA with other MOEAs

```matlab
platemo('algorithm', @ICMACHVGSA,    'problem', @RWMOP2, 'N', 120, 'maxFE', 30000);  % ICMA-HVGSA
platemo('algorithm', @CMOEACDCHVGSA, 'problem', @RWMOP2, 'N', 120, 'maxFE', 30000);  % CMOEA-CD-HVGSA
```

### Standalone HVGSA (local search only)

```matlab
algorithm = generateHVGSA(struct('eta', 1e-3, 'gradient_method', 'CGSA_n'));
platemo('algorithm', algorithm, 'problem', @RWMOP10, 'N', 5, 'maxFE', 100000);
```

## Reproducing the Paper's Experiments

All pipelines live in `PlatEMO/Benchmarks/` and are run section by section (MATLAB cell mode):

1. **Main benchmark & MOEA-integration study** — `BenchmarkPipeline.m`. Edit the `algorithms` and `problems` arrays at the top (the paper's ablation and sensitivity groups are included as commented presets), then run the sections in order: experiments → metrics → statistics → tables/plots.
2. **Scalability study** (DAS-CMaOP1, varying n and M) — `DASCMaOPPipeline.m`.
3. **Sensitivity analysis** — `RWMOPSensitivityAnalysis.m`.

Notes:

- **Reference Pareto fronts.** Normalized HV/IGD metrics require the estimated reference fronts in `PlatEMO/Info/ReferencePF/` (included, ~3 MB). They can be regenerated with `Benchmarks/PipelineFunctions/generateReferencePF.m`, but this is expensive (21 runs × 3 algorithms × 1.2M evaluations per problem).
- **Shared initial populations.** Pipelines generate deterministic initial populations in `PlatEMO/Info/InitialPopulation/` automatically, so all algorithms start from identical populations per run.
- **Figures.** Scripts in `PlatEMO/ProduceImage/` regenerate the paper's illustrations (flowchart panels, hypervolume-space sketches, standalone HVGSA/HVGA runs on RCM10/RCM18, CBOP examples). Convergence/critical-difference plots are produced by the pipeline's visualization sections.

## Acknowledgments

- Built on **PlatEMO**: Ye Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, "PlatEMO: A MATLAB platform for evolutionary multi-objective optimization," *IEEE Computational Intelligence Magazine*, 12(4): 73–87, 2017.
- The RCM problems (`RWMOP1`–`RWMOP50`): A. Kumar et al., "A benchmark-suite of real-world constrained multi-objective optimization problems and some baseline results," *Swarm and Evolutionary Computation*, 2021.
- Hypervolume computation uses the WFG algorithm via the **STK toolbox**.

## Citation

```bibtex
@article{zhang2026chvgsa,
  author  = {Zhang, Kenneth M. and others},
  title   = {Rapidly Handling Constrained Multi-objective Optimization Problems
             with Hypervolume Gradient Subspace Approximation},
  journal = {IEEE Transactions on Evolutionary Computation},
  year    = {2026},
  note    = {Accepted}
}
```
