# *United States SARS-CoV-2 Variant Nowcast Hub*

**Submissions accepted** every Wednesday by 8pm ET, starting October 9, 2024

## Introduction
This document provides guidelines for the United States SARS-CoV-2 Variant Nowcast Hub, which is planned to launch on October 9, 2024. This modeling hub has been designed by researchers from the [US CDC Center of Forecasting and Outbreak Analytics (CFA)](https://www.cdc.gov/forecast-outbreak-analytics/index.html) and [the Reich Lab at UMass Amherst](https://reichlab.io/), in consultation with folks from [the NextStrain project](https://nextstrain.org/). (An early draft of the guidelines, including comments, can be found [here](https://github.com/reichlab/variant-nowcast-hub/discussions/18).) 

Collaborative and open forecast hubs have emerged as a valuable way to centralize and coordinate predictive modeling efforts for public health. In realms where multiple teams are tackling the same problem using different data inputs and/or modeling methodologies, a hub can standardize targets in ways that facilitate model comparison and the integration of outputs from multiple models into public health practice. This hub uses the open-source architecture and data standards developed by the [hubverse](https://hubverse.io/).

While SARS-CoV-2 variant dynamics received most attention from the scientific community in 2021 and 2022, SARS-CoV-2 genomic sequences continue to be generated, and trends in variant frequencies will continue to impact transmission across the US and the world. From a modeling perspective, there is less consensus about a standard way to represent model outputs for multivariate variant frequency predictions than there is for other outcomes. Therefore, a key reason for building and launching this nowcast hub is to help learn about the right way to evaluate and communicate variant dynamics in a collaborative modeling effort, potentially not just for SARS-CoV-2 but also for other rapidly evolving pathogens.

## Submitting to the hub

**How to submit**: Any team wishing to submit a set of nowcasts to the hub may submit a pull request to this repository with a valid submission file in parquet format. The submission file must be located in `model-output/<team_abbr>-<model_abbr>/` (where `<team_abbr>` and `<model_abbr>` are the abbreviated names of your team and your model, respectively, that match the fields in your model metadata file), and the submission file must be named `YYYY-MM-DD-<team>-<model>.parquet` where `YYYY-MM-DD` is the date of the Wednesday on which the submission is due. Teams must also submit a model metadata file (see details [below](#model-metadata)). 

**Deadline**: Submissions are due at 8pm ET every Wednesday. This time was chosen to give modelers time in the beginning of the week to run and adjust models and stakeholders time at the end of the week to incorporate preliminary results into discussions or decision making.

## What will modelers be asked to predict?
We ask modeling teams to submit predictions of frequencies of the predominant SARS-CoV-2 clades in the US, at a daily timescale and the geographic resolution of all 50 United States plus Washington DC and Puerto Rico. We will not solicit estimates for the US, in part because evaluating this quantity is not straightforward due to the heterogeneity in levels of infections and sequencing across locations. Details about these choices follow in subsections below. The hub will solicit predictions of frequencies (i.e., numbers between 0 and 1) associated with each clade or group of clades, for a particular location and a particular day.

### Predicted clades
Each week the hub designates up to nine NextStrain clades with the highest reported prevalence of at least 1% across the US in any of the three complete [USA/CDC epidemiological weeks](https://ndc.services.cdc.gov/wp-content/uploads/MMWR_Week_overview.pdf) (a.k.a. MMWR weeks) preceding the Wednesday submission date. Any clades with prevalence of less than 1% are grouped into an “other” category for which predictions of combined prevalence are also collected. No more than 10 clades (including “other”) are selected in a given week. For details on the workflow that generates this list each week, see the [clade list section](#clade-list) below.

### Prediction horizon
Genomic sequences tend to be reported weeks after being collected. Therefore, recent data is subject to quite a lot of backfill. For this reason, the hub collects "nowcasts" (predictions for data relevant to times prior to the current time, but not yet observed) and some "forecasts" (predictions for future observations). Counting the Wednesday submission date as a prediction horizon of zero, we collect daily-level predictions for 10 days into the future (the Saturday that ends the epidemic week after the Wednesday submission) and -31 days into the past (the Sunday that starts the epidemic week four weeks prior to the Wednesday submission date). Overall, six weeks (42 days) of predicted values are solicited each week.

### Model output format
This hub follows [hubverse](https://hubverse.io/) data standards. Submissions must include either mean outputs, or sample-based model outputs. If sample-based model outputs are submitted and means are not, modelers should assume that these samples may be used to compute a mean prediction which may be scored. 

We use the term “model task” below to refer to a prediction for a specific clade, location and horizon. For example, if mean model outputs are submitted, there will be one value between 0 and 1 for each model task. The submitted values for all clades must sum to 1 (within +/- 0.001) for a given location and horizon.
As we will describe in further detail below, the target for prediction is the proportion of circulating viral genomes for a given location and target date amongst infected individuals that are sequenced for SARS-CoV-2.

To submit probabilistic predictions, a [sample format](https://hubverse.io/en/latest/user-guide/sample-output-type.html) is used to encode samples from the predictive distribution for each model task. The hub requires exactly 100 samples for each model task. One key advantage to submitting sample-based output is that dependence can be encoded across horizons (corresponding to trajectories of variant prevalence over time), or even across locations (see details in [Hubverse sample model-output specifications](https://hubverse.io/en/latest/user-guide/sample-output-type.html#compound-modeling-tasks)). For this hub, we require that samples be submitted in such a way as to imply that they are structured into trajectories across clades and horizons. (See following section for how variants are classified into clade categories.) This means that 

a) at each location and horizon a common sample ID (in the `ouput_type_id` column) ensures that the clade proportions sum to 1, and
b) for each location and clade, common sample IDs across horizons allows us to draw trajectories by clade.

This specification corresponds to a hubverse-style “compound modeling task” that includes the following fields: "reference_date", "location". Samples then capture dependence across the complementary set of task ids: “horizon”, “clade”.

We note that sample IDs present in the `output_type_id` column of submissions are not necessarily inherent properties of how the samples are generated, as they can be changed post-hoc by a modeler. For example, some models may make nowcasts independently by horizon but the samples could be tied together either randomly or via some other correlation structure or secondary model to assign sample IDs that are consistent across horizons. As another example, some models may make forecasts that have joint dependence structure across locations as well as horizons. Sample IDs can be shared across locations as well, but this is not required for the submission to pass validation.

To be included in the hub ensemble model, samples must be submitted and the mean forecast for the hub ensemble will be obtained as a summary of sample predictions.

## <a name="model-metadata"></a>Model metadata
TODO

## Data created and stored by the hub

### <a name="clade-list"></a>Clade list
Early Monday morning (~3am ET) prior to a Wednesday on which submissions are due, the hub generates a JSON file with two high-level properties:

1. `clades`: an array of [NextClade clade names](https://clades.nextstrain.org/about) that will be accepted in submission files for the upcoming deadline.
2. `meta`: metadata relevant to the upcoming round, including links to the Nextstrain sequence information and reference tree used to generate the above `clades` array.

The JSON file will live in the `auxiliary-data/modeled-clades/` directory of the repository and will be named “YYYY-MM-DD.json” where “YYYY-MM-DD” is the date of the Wednesday on which submissions are due

This clade selection is based on the ["full open" NextStrain sequence metadata files](https://docs.nextstrain.org/projects/ncov/en/latest/reference/remote_inputs.html#remote-inputs-open-files), in particular [this file](https://data.nextstrain.org/files/ncov/open/metadata.tsv.zst) which is loaded and analyzed using [this script](https://github.com/reichlab/virus-clade-utils/blob/main/src/virus_clade_utils/get_clade_list.py). The NextStrain files are [typically updated daily in the late evening US eastern time](https://github.com/nextstrain/forecasts-ncov/actions/workflows/update-ncov-open-clade-counts.yaml) (it is only updated when new data are available). The hub pulls the most recent version of the file when the workflow runs each week. The precise lineage assignment model (sometimes referred to as a “reference tree”) that was used as well as the version of raw sequence data is stored as metadata, to facilitate reproducibility and evaluation. 

### Tasks for primary evaluation
As described [below](#eval-challenges), only certain model tasks will be included in the primary model evaluation. These will include all clade frequencies for location-date pairs for which there are no observed specimens reported as of Wednesday night. A file that specifies which location-date pairs will be eligible for inclusion in the primary analysis will be generated and stored in the hub repository after the submission deadline passes.

### Target data for evaluation
Ninety days after each round closes, a script will generate a file containing summarized counts of selected clades for that round (including "other") for each location and date in the prediction window. These clade assignments will be made using the reference tree that was current when the submission round was open three months prior. While such "target data" files will not be suitable for training models (they will contain only limited dates and aggregated clades), they will be used as snapshots for evaluation. 


## Model evaluation

We note that due to some of the challenges outlined just below, upon launch of the hub, final evaluation plans remain a work in progress. However, below we outline a sketch of the possible evaluation schemes.

### <a name="eval-challenges"></a>Evaluation challenges
Several features of these data in particular make evaluations tricky. 

1. Data for some model tasks may be partially observed at the time nowcasts and forecasts are made. The hub encourages teams to submit predictions of “true” underlying clade frequencies that will vary more or less smoothly, if sometimes steeply, over time. When some observations are partially observed at the time of nowcast submissions, it could be to the modeler’s advantage to predict a value that is close to the frequency observed at the time the forecast is made, thus deviating from the underlying (likely smooth) function the model would predict in the absence of data. To incentivize “honest” nowcasts that do not shift predictions for time-points with partial observations, we will only evaluate locations and dates for which no data have yet been reported at the time submissions are due (Wednesday evening). 
One implication of this decision is that different numbers of days may be evaluated for some locations when compared with others.

2. The reference phylogenetic tree that defines clades changes over time. Nowcasts and forecasts will be evaluated against whatever sequence data is available 90 days after the deadline that a set of predictions were submitted for. Additionally, those sequences will be assigned a clade based on the reference tree that was used to generate the list of predicted clades on the Monday prior to the submission date. This means that new sequences that emerge in the time since the predictions were made will still be classified as they would have been when predictions were made.

3. The variance in the eventually observed clade counts depends on the eventual sample size, or number of sequences tested on a particular day. With a large number of sequences, the variance of the clade counts would tend to be larger and with a small number of sequences the variance would be smaller. However, the number of sequences itself is not of particular epidemiological interest. The evaluation plan introduced below evaluates the counts assuming they follow a multinomial observation model with sample size equal to the number of sequences collected on the target date and location that have been reported as of the evaluation date, so as to eliminate the nuisance parameter of the count variance.  


### Notation

We will collect nowcasts for $\theta$, a $K$-vector, where $K$ is the number of clades we are interested in, and whose $k$th element, $\theta_k$ , is the true proportion of all current SARS-CoV-2 infections which are clade $k$. We observe $C = (C_1, … , C_K)$, the vector of observed counts for each of the $K$ clades of interest for a particular location and target date, and let $N = \sum_k C_k$ be the total number of sequences collected for that date and location (for simplicity here, we are omitting subscripts for date and location). Variation in $C$ depends on the total number of sequenced specimens, $N$. Thus, accurate nowcasts of the observed $C$ would require teams to model and forecast $N$, which is not of epidemiological interest.

### Point forecast evaluation

Point predictions $\hat \theta$ will be scored directly using the categorical Brier score, comparing the predicted clade proportions of sequences to the observed clade proportions on a specific day in a specific location [[Susswein et al. 2023](https://www.medrxiv.org/content/10.1101/2023.01.02.23284123v4)].

### Probabilistic forecast evaluation

Since full predictive distributions of clade probabilities are solicited as samples of a predictive distribution, we aim to evaluate the full predictive distribution using a precise scoring procedure, however the precise details of this evaluation are still being worked out. The working proposal for probabilistic forecast evaluation is as follows.

To avoid a situation where the distribution of the prediction target depends on $N$, the total number of sequenced specimens on a given day, nowcasts are to be submitted in the form of 100 samples $\hat \theta^{(1)}, …, \hat \theta^{(100)}$ from the predictive distribution for $\theta$. Historical data show that 90 days is sufficient time for nearly all sequences to be tested and reported and therefore for $C$ to represent a stable estimate of relative clade prevalences. Therefore, 90 days after each submission date, the hub will use the total number of sequences collected, $N$, and the clade proportion nowcasts $\hat \theta^{(1)}, …, \hat \theta^{(100)}$ to generate nowcasts for observed clade counts, $\hat C$, by sampling from multinomial distributions. Specifically, the hub will generate predictions for observed clade counts $\hat C^{(1)}, …, \hat C^{(100)}$ where each $\hat C^{(s)}$ is drawn from a $Multinomial(N, \hat \theta^{(s)})$ distribution, resulting in 10,000 total draws to evaluate against the observed counts for each clade, day, and location.

The use of a multinomial distribution assumes that, conditional on the mean prevalence, clade assignments for the sequenced samples are independent and have probability of being in each clade equal to the population probabilities $\theta$. Furthermore, while the use of a multinomial distribution with size $N$ gets around the need for teams to model the number of sequences at a given time, it also introduces a specific assumption about the variation in the observation process that takes probabilities and a size $N$ and turns them into expected observed counts of sequences of each clade.  If a team does not believe these assumptions, they may wish to modify their distribution for $\theta$ accordingly. For example, if a team believes that an overdispersed Dirichlet-Multinomial distribution would more accurately model the variation in future observations, they should add dispersion to their distribution for $\theta$. Or if a team believes that sampling is biased and some clades are underrepresented in the reported data, they may wish to modify their estimate of $\theta$ to reflect the reporting process. <!--TODO: realizing that this is counter to the above statement where we request that teams submit forecasts of true latent clade frequency estimates among infections. We might need to clarify by saying among infections that get sequenced and reported --> 

These count forecasts $\hat C^{(1)}, …, \hat C^{(100)}$ will be scored on the observed counts $C$, using the energy score [[Gneiting et al. 2008](https://link.springer.com/article/10.1007/s11749-008-0114-x),[ Jordan et al. 2019](https://cran.r-project.org/web/packages/scoringRules/vignettes/article.pdf)], a proper scoring rule for multivariate data, which uses samples from the forecast distribution to compute scores. We note that the energy score procedure described above scores predictions (the probabilities) that can be seen as parameters of the distribution for the count observations, under the stated parametric distributional assumption. But the probabilities are not explicitly predictions of the count observations themselves.

One possible problem with this evaluation approach is that there is an element of stochasticity to the scores, as the scores are computed using counts based on random draws from a multinomial distribution. We have conducted simulation studies that indicate that the chances of one model that is truly closer to the truth than another would be given a worse score, due to the randomness of the multinomial draws or the Monte Carlo error present due to only having 100 samples of the posterior distribution, is low, although non-zero.
One alternative would be to perform exact, or approximations to exact, energy score calculations, but this may be infeasible due to the size of the sample space.
Another alternative could be to use the log-score to evaluate the predictive distribution, although preliminary simulations have shown that this may yield unstable score estimates when the number of specimens, $N$, is large.

An additional alternative scoring option would be to compute Brier scores on each submitted sample using the draws from the multinomial observation model desscribed above. This would return a distribution of Brier scores that could be summarized across samples, locations, and dates. 

### Score aggregation

Scores will be primarily reported as aggregated scores across all locations and dates. However, we will also report scores for individual locations and dates.

