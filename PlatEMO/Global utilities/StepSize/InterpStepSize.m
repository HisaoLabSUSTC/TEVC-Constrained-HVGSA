function [accepted_etas, eta] = InterpStepSize(eta, TRY_THRESH, x0flat, gsd, U, Problem, cref, d, lambda, V, y0flat, c0flat, c_1)
    counter = 1;
    accepted_etas = [eta];
    phi0 = CHVGenerator(y0flat,c0flat,cref,Problem.M,[],[]);
    numerator = d' * lambda;
    denom = norm(V * lambda + 1e-4);
    phi_prime0 = numerator/denom;

    while counter < TRY_THRESH && eta > 0.1
        % trigger
        x1flat = x0flat + gsd .* eta;
        x1 = reshape(x1flat, [], U)';
        GSA_initial = Problem.Evaluation(reshape(x1flat, [], U)');
        [x1, y1, c1, ~, y1flat, c1flat] = QuickAssign(GSA_initial);

        HVC_new = CHVGenerator(y1flat,c1flat,cref,Problem.M,[],[]);

        if HVC_new >= phi0 + c_1 * eta * phi_prime0
            disp("Accepted");
            prev_eta = max(eta, 1);
            break;
        else
            if counter == 1
                %% Quadratic interpolation
                eta_new = -(eta^2 * phi_prime0) / (2*(HVC_new - phi0 - eta*phi_prime0));
            else
                %% Cubic interpolation
                F_old = phi_old - phi0 - phi_prime0 * eta_old;
                F_current = HVC_new - phi0 - phi_prime0 * eta;
                denom_cubic = eta_old^2 * eta^2 * (eta - eta_old);
                a = ( eta_old^2 * F_current - eta^2 * F_old ) / denom_cubic;
                b = (-eta_old^3 * F_current + eta^3 * F_old) / denom_cubic;
                disc = b^2 - 3*a*phi_prime0;
                if disc < 0 || abs(3*a) < 1e-10
                    eta_new = eta / 2;
                else
                    eta_new = (-b + sqrt(disc))/(3*a);
                    if eta_new <= 0 || eta_new >= eta || abs(eta_new - eta) < 0.1*eta
                        eta_new = eta / 2;
                    end
                end
            end
            eta_old = eta;
            phi_old = HVC_new;
            eta = eta_new;
            accepted_etas = [accepted_etas, eta];
        end
        counter = counter + 1;
    end
end